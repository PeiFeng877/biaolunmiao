from __future__ import annotations

import hashlib
import hmac
import json
import logging
import secrets
from dataclasses import dataclass
from datetime import timedelta
from typing import Protocol
from uuid import uuid4

from sqlalchemy import delete, select
from sqlalchemy.exc import SQLAlchemyError
from sqlalchemy.orm import Session

from app.core.config import get_settings
from app.core.error_codes import ErrorCode
from app.core.exceptions import AppException
from app.core.time import UTC
from app.models import SmsVerificationCode
from app.models.entities import SmsVerificationStatus
from app.services.common import now_utc

logger = logging.getLogger(__name__)


def normalize_cn_phone(phone: str) -> str:
    digits = "".join(ch for ch in phone if ch.isdigit())
    if digits.startswith("86") and len(digits) == 13:
        digits = digits[2:]
    if len(digits) != 11 or not digits.startswith("1") or digits[1] not in "3456789":
        raise AppException(ErrorCode.PHONE_INVALID, "请输入有效的中国大陆手机号", 422)
    return f"+86{digits}"


def phone_without_country_code(phone_e164: str) -> str:
    return phone_e164.removeprefix("+86")


def ensure_aware_utc(value):
    if value.tzinfo is None:
        return value.replace(tzinfo=UTC)
    return value.astimezone(UTC)


@dataclass(frozen=True)
class SmsSendResult:
    request_id: str
    provider: str


class SmsAuthProvider(Protocol):
    provider_name: str

    def send_code(self, *, phone_e164: str, code: str, out_id: str) -> SmsSendResult: ...


class MockSmsAuthProvider:
    provider_name = "mock"

    def send_code(self, *, phone_e164: str, code: str, out_id: str) -> SmsSendResult:
        return SmsSendResult(request_id=f"mock-{uuid4()}", provider=self.provider_name)


class AliyunSmsAuthProvider:
    provider_name = "aliyun"

    def __init__(self) -> None:
        self.settings = get_settings()

    def send_code(self, *, phone_e164: str, code: str, out_id: str) -> SmsSendResult:
        from alibabacloud_tea_openapi.exceptions import AlibabaCloudException

        client, models = self._sdk_modules()
        valid_minutes = max(1, self.settings.aliyun_sms_auth_code_ttl_seconds // 60)
        request = models.SendSmsVerifyCodeRequest(
            phone_number=phone_without_country_code(phone_e164),
            country_code="86",
            sign_name=self.settings.aliyun_sms_auth_sign_name,
            template_code=self.settings.aliyun_sms_auth_template_code,
            out_id=out_id,
            template_param=json.dumps(
                {
                    "code": code.strip(),
                    "min": str(valid_minutes),
                },
                ensure_ascii=False,
            ),
            code_type=1,
            code_length=len(code.strip()),
            valid_time=valid_minutes,
            duplicate_policy=1,
            interval=self.settings.aliyun_sms_auth_resend_interval_seconds,
        )
        if self.settings.aliyun_sms_auth_scheme_name:
            request.scheme_name = self.settings.aliyun_sms_auth_scheme_name

        try:
            response = client.send_sms_verify_code(request)
        except AlibabaCloudException as exc:
            logger.exception("Aliyun SMS send failed phone=%s", phone_e164, exc_info=exc)
            raise AppException(
                ErrorCode.PHONE_AUTH_NOT_AVAILABLE,
                "短信认证暂时不可用，请稍后再试",
                503,
                details={
                    "stage": "provider_send",
                    "provider": self.provider_name,
                    "providerCode": getattr(exc, "code", None),
                    "providerRequestId": getattr(exc, "request_id", None),
                },
            ) from exc
        body = response.body
        if not body or not body.success:
            provider_code = body.code if body else None
            if provider_code == "biz.FREQUENCY":
                raise AppException(
                    ErrorCode.PHONE_CODE_TOO_FREQUENT,
                    "验证码发送过于频繁，请稍后再试",
                    429,
                    details={
                        "stage": "provider_send",
                        "provider": self.provider_name,
                        "providerCode": provider_code,
                        "providerRequestId": body.request_id if body else None,
                    },
                )
            raise AppException(
                ErrorCode.PHONE_AUTH_NOT_AVAILABLE,
                "短信认证暂时不可用，请稍后再试",
                503,
                details={
                    "stage": "provider_send",
                    "provider": self.provider_name,
                    "providerCode": provider_code,
                    "providerRequestId": body.request_id if body else None,
                },
            )
        provider_request_id = (body.request_id or "").strip() if body else ""
        fallback_code = (body.code or "").strip() if body else ""
        request_id = provider_request_id or (
            fallback_code if fallback_code and fallback_code != "OK" else f"aliyun-{uuid4()}"
        )
        return SmsSendResult(request_id=request_id, provider=self.provider_name)

    def _sdk_modules(self):
        from alibabacloud_dypnsapi20170525 import models as dypns_models
        from alibabacloud_dypnsapi20170525.client import Client as DypnsClient
        from alibabacloud_tea_openapi import models as open_api_models

        config = open_api_models.Config(
            access_key_id=self.settings.aliyun_sms_auth_access_key_id,
            access_key_secret=self.settings.aliyun_sms_auth_access_key_secret,
            endpoint="dypnsapi.aliyuncs.com",
        )
        return DypnsClient(config), dypns_models

def get_sms_auth_provider() -> SmsAuthProvider:
    settings = get_settings()
    if settings.sms_auth_provider == "mock":
        return MockSmsAuthProvider()
    return AliyunSmsAuthProvider()


class SmsAuthService:
    def __init__(self, provider: SmsAuthProvider | None = None) -> None:
        self.settings = get_settings()
        self.provider = provider or get_sms_auth_provider()

    def send_sign_in_code(self, db: Session, phone: str) -> str:
        phone_e164 = normalize_cn_phone(phone)
        try:
            latest = self._latest_record(db, phone_e164)
        except SQLAlchemyError as exc:
            logger.exception("Phone auth latest record query failed phone=%s", phone_e164, exc_info=exc)
            raise self._phone_auth_unavailable(stage="latest_record_query", exc=exc) from exc
        now = now_utc()
        latest_created_at = ensure_aware_utc(latest.created_at) if latest is not None else None
        if (
            latest
            and latest.status == SmsVerificationStatus.PENDING
            and latest_created_at is not None
            and now < latest_created_at + timedelta(seconds=self.settings.aliyun_sms_auth_resend_interval_seconds)
        ):
            raise AppException(ErrorCode.PHONE_CODE_TOO_FREQUENT, "验证码发送过于频繁，请稍后再试", 429)

        issued_code = self._issue_sign_in_code()
        out_id = f"sign-in-{uuid4()}"
        try:
            result = self.provider.send_code(phone_e164=phone_e164, code=issued_code, out_id=out_id)
        except AppException:
            raise
        except Exception as exc:
            logger.exception("Phone auth provider send failed phone=%s", phone_e164, exc_info=exc)
            raise self._phone_auth_unavailable(stage="provider_send_unknown", exc=exc) from exc

        try:
            db.add(
                SmsVerificationCode(
                    phone_e164=phone_e164,
                    request_id=result.request_id,
                    code_digest=self._digest_code(phone_e164=phone_e164, code=issued_code),
                    provider=result.provider,
                    biz_type="sign_in",
                    expires_at=now + timedelta(seconds=self.settings.aliyun_sms_auth_code_ttl_seconds),
                )
            )
            db.commit()
        except SQLAlchemyError as exc:
            db.rollback()
            logger.exception(
                "Phone auth verification record save failed phone=%s request_id=%s",
                phone_e164,
                result.request_id,
                exc_info=exc,
            )
            raise self._phone_auth_unavailable(
                stage="verification_record_save",
                request_id=result.request_id,
                exc=exc,
            ) from exc
        return phone_e164

    def verify_sign_in_code(self, db: Session, phone: str, code: str) -> str:
        phone_e164 = normalize_cn_phone(phone)
        record = self._latest_record(db, phone_e164)
        if record is None:
            raise AppException(ErrorCode.PHONE_CODE_INVALID, "验证码错误", 401)

        now = now_utc()
        if record.status != SmsVerificationStatus.PENDING:
            raise AppException(ErrorCode.PHONE_CODE_INVALID, "验证码错误", 401)
        if ensure_aware_utc(record.expires_at) <= now:
            record.status = SmsVerificationStatus.EXPIRED
            db.add(record)
            db.commit()
            raise AppException(ErrorCode.PHONE_CODE_EXPIRED, "验证码已过期", 401)
        if not (record.code_digest or "").strip():
            record.status = SmsVerificationStatus.FAILED
            db.add(record)
            db.commit()
            raise AppException(ErrorCode.PHONE_CODE_EXPIRED, "验证码已失效，请重新获取", 401)

        record.attempt_count += 1
        record.last_attempt_at = now
        db.add(record)
        db.commit()
        if record.attempt_count > self.settings.aliyun_sms_auth_max_attempts:
            record.status = SmsVerificationStatus.FAILED
            db.add(record)
            db.commit()
            raise AppException(ErrorCode.PHONE_CODE_INVALID, "验证码错误次数过多，请重新获取", 401)

        if not self._matches_code(record=record, phone_e164=phone_e164, code=code):
            if record.attempt_count >= self.settings.aliyun_sms_auth_max_attempts:
                record.status = SmsVerificationStatus.FAILED
                db.add(record)
                db.commit()
            raise AppException(ErrorCode.PHONE_CODE_INVALID, "验证码错误", 401)
        record.status = SmsVerificationStatus.VERIFIED
        record.verified_at = now
        db.add(record)
        db.commit()
        return phone_e164

    def clear_user_records(self, db: Session, phone_e164: str) -> None:
        db.execute(delete(SmsVerificationCode).where(SmsVerificationCode.phone_e164 == phone_e164))
        db.commit()

    def _latest_record(self, db: Session, phone_e164: str) -> SmsVerificationCode | None:
        return db.scalar(
            select(SmsVerificationCode)
            .where(
                SmsVerificationCode.phone_e164 == phone_e164,
                SmsVerificationCode.biz_type == "sign_in",
            )
            .order_by(SmsVerificationCode.created_at.desc())
        )

    def _issue_sign_in_code(self) -> str:
        if self.provider.provider_name == "mock":
            return "1234"
        return "".join(secrets.choice("0123456789") for _ in range(4))

    def _digest_code(self, *, phone_e164: str, code: str) -> str:
        payload = f"{phone_e164}:{code.strip()}".encode()
        secret = self.settings.secret_key.encode()
        return hmac.new(secret, payload, hashlib.sha256).hexdigest()

    def _matches_code(self, *, record: SmsVerificationCode, phone_e164: str, code: str) -> bool:
        expected = (record.code_digest or "").strip()
        actual = self._digest_code(phone_e164=phone_e164, code=code)
        return bool(expected) and hmac.compare_digest(expected, actual)

    @staticmethod
    def _phone_auth_unavailable(
        *,
        stage: str | None = None,
        request_id: str | None = None,
        exc: Exception | None = None,
    ) -> AppException:
        details = None
        if stage or request_id or exc is not None:
            details = {
                "stage": stage,
                "providerRequestId": request_id,
                "errorType": type(exc).__name__ if exc is not None else None,
            }
        return AppException(
            ErrorCode.PHONE_AUTH_NOT_AVAILABLE,
            "短信认证暂时不可用，请稍后再试",
            503,
            details=details,
        )

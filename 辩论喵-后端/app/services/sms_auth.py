from __future__ import annotations

from dataclasses import dataclass
from datetime import timedelta
from typing import Protocol
from uuid import uuid4

from sqlalchemy import delete, select
from sqlalchemy.orm import Session

from app.core.config import get_settings
from app.core.error_codes import ErrorCode
from app.core.exceptions import AppException
from app.core.time import UTC
from app.models import SmsVerificationCode
from app.models.entities import SmsVerificationStatus
from app.services.common import now_utc


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

    def send_code(self, *, phone_e164: str) -> SmsSendResult: ...

    def verify_code(self, *, phone_e164: str, code: str) -> None: ...


class MockSmsAuthProvider:
    provider_name = "mock"

    def send_code(self, *, phone_e164: str) -> SmsSendResult:
        return SmsSendResult(request_id=f"mock-{uuid4()}", provider=self.provider_name)

    def verify_code(self, *, phone_e164: str, code: str) -> None:
        if code.strip() != "123456":
            raise AppException(ErrorCode.PHONE_CODE_INVALID, "验证码错误", 401)


class AliyunSmsAuthProvider:
    provider_name = "aliyun"

    def __init__(self) -> None:
        self.settings = get_settings()

    def send_code(self, *, phone_e164: str) -> SmsSendResult:
        client, models = self._sdk_modules()
        request = models.SendSmsVerifyCodeRequest(
            phone_number=phone_without_country_code(phone_e164),
            country_code="86",
            sign_name=self.settings.aliyun_sms_auth_sign_name,
            template_code=self.settings.aliyun_sms_auth_template_code,
            valid_time=max(1, self.settings.aliyun_sms_auth_code_ttl_seconds // 60),
        )
        if self.settings.aliyun_sms_auth_scheme_name:
            request.scheme_name = self.settings.aliyun_sms_auth_scheme_name

        response = client.send_sms_verify_code(request)
        body = response.body
        if not body or not body.success:
            raise AppException(
                ErrorCode.PHONE_AUTH_NOT_AVAILABLE,
                body.message if body and body.message else "短信验证码发送失败",
                503,
            )
        request_id = body.request_id or body.code or f"aliyun-{uuid4()}"
        return SmsSendResult(request_id=request_id, provider=self.provider_name)

    def verify_code(self, *, phone_e164: str, code: str) -> None:
        client, models = self._sdk_modules()
        request = models.CheckSmsVerifyCodeRequest(
            phone_number=phone_without_country_code(phone_e164),
            country_code="86",
            verify_code=code.strip(),
        )
        if self.settings.aliyun_sms_auth_scheme_name:
            request.scheme_name = self.settings.aliyun_sms_auth_scheme_name

        response = client.check_sms_verify_code(request)
        body = response.body
        if not body or not body.success:
            message = body.message if body and body.message else "短信验证码校验失败"
            raise AppException(ErrorCode.PHONE_CODE_INVALID, message, 401)

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
        latest = self._latest_record(db, phone_e164)
        now = now_utc()
        latest_created_at = ensure_aware_utc(latest.created_at) if latest is not None else None
        if (
            latest
            and latest.status == SmsVerificationStatus.PENDING
            and latest_created_at is not None
            and now < latest_created_at + timedelta(seconds=self.settings.aliyun_sms_auth_resend_interval_seconds)
        ):
            raise AppException(ErrorCode.PHONE_CODE_TOO_FREQUENT, "验证码发送过于频繁，请稍后再试", 429)

        result = self.provider.send_code(phone_e164=phone_e164)
        db.add(
            SmsVerificationCode(
                phone_e164=phone_e164,
                request_id=result.request_id,
                provider=result.provider,
                biz_type="sign_in",
                expires_at=now + timedelta(seconds=self.settings.aliyun_sms_auth_code_ttl_seconds),
            )
        )
        db.commit()
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

        record.attempt_count += 1
        record.last_attempt_at = now
        db.add(record)
        db.commit()
        if record.attempt_count > self.settings.aliyun_sms_auth_max_attempts:
            record.status = SmsVerificationStatus.FAILED
            db.add(record)
            db.commit()
            raise AppException(ErrorCode.PHONE_CODE_INVALID, "验证码错误次数过多，请重新获取", 401)

        try:
            self.provider.verify_code(phone_e164=phone_e164, code=code)
        except AppException:
            if record.attempt_count >= self.settings.aliyun_sms_auth_max_attempts:
                record.status = SmsVerificationStatus.FAILED
                db.add(record)
                db.commit()
            raise
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

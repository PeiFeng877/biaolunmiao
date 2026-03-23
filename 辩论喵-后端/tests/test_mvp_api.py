import json
import os
from datetime import UTC, datetime, timedelta
from pathlib import Path
from types import SimpleNamespace
from unittest.mock import patch

from cryptography.hazmat.primitives import serialization
from cryptography.hazmat.primitives.asymmetric import rsa
from fastapi.testclient import TestClient
from jose import jwt
from jose.utils import base64url_encode
from pydantic import ValidationError
from sqlalchemy import select
from sqlalchemy.orm import Session

# 测试使用独立 sqlite，避免依赖本地 postgres。
os.environ.setdefault("DATABASE_URL", f"sqlite:///{Path(__file__).parent / 'test.db'}")
os.environ.setdefault("ENABLE_DEBUG_TOKEN", "true")
os.environ.setdefault("APP_ENV", "local")
os.environ.setdefault("ALLOW_INSECURE_APPLE_TOKEN_VALIDATION", "true")

from app.core.config import Settings, get_settings
from app.core.exceptions import AppException
from app.db.base import Base
from app.db.session import engine
from app.main import app
from app.models import SmsVerificationCode, User, UserAuthIdentity
from app.models.entities import UserStatus
from app.services.sms_auth import AliyunSmsAuthProvider, SmsAuthService, SmsSendResult

client = TestClient(app)


def setup_function() -> None:
    Base.metadata.drop_all(bind=engine)
    Base.metadata.create_all(bind=engine)


def _token(public_id: str, nickname: str) -> str:
    res = client.post(
        "/api/v1/auth/debug-token",
        json={"public_id": public_id, "nickname": nickname},
    )
    assert res.status_code == 200
    return res.json()["access_token"]


def _headers(token: str) -> dict[str, str]:
    return {"Authorization": f"Bearer {token}"}


def _rpc(action: str, params: dict | None = None, token: str | None = None):
    headers: dict[str, str] = {}
    if token:
        headers["Authorization"] = f"Bearer {token}"
    return client.post(
        "/api",
        json={
            "action": action,
            "params": params or {},
            "request_id": "rpc-test-request-id",
        },
        headers=headers,
    )


def _debug_bundle(public_id: str, nickname: str) -> dict[str, str]:
    res = client.post(
        "/api/v1/auth/debug-token",
        json={"public_id": public_id, "nickname": nickname},
    )
    assert res.status_code == 200
    return res.json()


def _rsa_material() -> tuple[bytes, dict[str, str]]:
    private_key = rsa.generate_private_key(public_exponent=65537, key_size=2048)
    private_pem = private_key.private_bytes(
        encoding=serialization.Encoding.PEM,
        format=serialization.PrivateFormat.PKCS8,
        encryption_algorithm=serialization.NoEncryption(),
    )
    public_numbers = private_key.public_key().public_numbers()

    def _encode_int(value: int) -> str:
        size = max(1, (value.bit_length() + 7) // 8)
        return base64url_encode(value.to_bytes(size, "big")).decode("utf-8")

    jwk_payload = {
        "kty": "RSA",
        "kid": "test-kid",
        "use": "sig",
        "alg": "RS256",
        "n": _encode_int(public_numbers.n),
        "e": _encode_int(public_numbers.e),
    }
    return private_pem, jwk_payload


def _signed_apple_token(
    *,
    audience: str = "com.wenwan.BianLunMiao",
    issuer: str = "https://appleid.apple.com",
    subject: str = "apple-user-001",
    expires_at: datetime | None = None,
) -> tuple[str, dict[str, str]]:
    private_pem, jwk_payload = _rsa_material()
    claims = {
        "iss": issuer,
        "aud": audience,
        "sub": subject,
        "exp": int((expires_at or (datetime.now(UTC) + timedelta(minutes=10))).timestamp()),
    }
    token = jwt.encode(claims, private_pem, algorithm="RS256", headers={"kid": jwk_payload["kid"]})
    return token, jwk_payload


def test_debug_token_rejects_too_long_public_id() -> None:
    res = client.post(
        "/api/v1/auth/debug-token",
        json={"public_id": "U" * 21, "nickname": "调试用户"},
    )

    assert res.status_code == 422
    assert res.json()["code"] == "VALIDATION_ERROR"


def test_auth_apple_accepts_valid_signed_token_in_prod(monkeypatch) -> None:
    token, jwk_payload = _signed_apple_token(subject="apple-prod-user")
    settings = get_settings()
    old_env = settings.app_env
    old_insecure = settings.allow_insecure_apple_token_validation
    old_audience = settings.apple_allowed_audiences

    monkeypatch.setattr(
        "app.services.apple_auth.AppleTokenValidator._load_jwks_payload",
        lambda self: [jwk_payload],
    )
    settings.app_env = "prod"
    settings.allow_insecure_apple_token_validation = False
    settings.apple_allowed_audiences = "com.wenwan.BianLunMiao"

    try:
        res = client.post(
            "/api/v1/auth/apple",
            json={"identity_token": token, "first_name": "辩论", "last_name": "喵"},
        )
    finally:
        settings.app_env = old_env
        settings.allow_insecure_apple_token_validation = old_insecure
        settings.apple_allowed_audiences = old_audience

    assert res.status_code == 200
    payload = res.json()
    assert payload["user"]["nickname"] == "辩论喵"
    assert payload["isNewUser"] is True
    assert payload["access_token"]
    assert payload["refresh_token"]


def test_auth_apple_marks_only_first_login_as_new_user(monkeypatch) -> None:
    token, jwk_payload = _signed_apple_token(subject="apple-repeat-user")

    monkeypatch.setattr(
        "app.services.apple_auth.AppleTokenValidator._load_jwks_payload",
        lambda self: [jwk_payload],
    )

    first = client.post(
        "/api/v1/auth/apple",
        json={"identity_token": token, "first_name": "新", "last_name": "用户"},
    )
    second = client.post(
        "/api/v1/auth/apple",
        json={"identity_token": token},
    )

    assert first.status_code == 200
    assert first.json()["isNewUser"] is True
    assert second.status_code == 200
    assert second.json()["isNewUser"] is False

    with Session(engine) as session:
        identity = session.scalar(
            select(UserAuthIdentity).where(
                UserAuthIdentity.provider == "apple",
                UserAuthIdentity.provider_subject == "apple-repeat-user",
            )
        )

    assert identity is not None


def test_auth_apple_recreates_deleted_account_as_new_user(monkeypatch) -> None:
    token, jwk_payload = _signed_apple_token(subject="apple-deleted-user")

    monkeypatch.setattr(
        "app.services.apple_auth.AppleTokenValidator._load_jwks_payload",
        lambda self: [jwk_payload],
    )

    first = client.post(
        "/api/v1/auth/apple",
        json={"identity_token": token, "first_name": "删", "last_name": "号"},
    )
    assert first.status_code == 200

    deleted = client.delete(
        "/api/v1/account",
        headers=_headers(first.json()["access_token"]),
    )
    assert deleted.status_code == 200

    second = client.post(
        "/api/v1/auth/apple",
        json={"identity_token": token},
    )

    assert second.status_code == 200
    second_payload = second.json()
    assert second_payload["isNewUser"] is True
    assert second_payload["user"]["id"] != first.json()["user"]["id"]

    me = client.get("/api/v1/users/me", headers=_headers(second_payload["access_token"]))
    assert me.status_code == 200
    assert me.json()["id"] == second_payload["user"]["id"]

    public_ids = [
        first.json()["user"]["publicId"],
        second_payload["user"]["publicId"],
    ]
    with Session(engine) as session:
        users = session.scalars(select(User).where(User.public_id.in_(public_ids))).all()

    assert len(users) == 2
    deleted_user = next(user for user in users if user.id == first.json()["user"]["id"])
    recreated_user = next(user for user in users if user.id == second_payload["user"]["id"])
    assert deleted_user.status == UserStatus.DELETED
    assert deleted_user.apple_sub is None
    assert recreated_user.status == UserStatus.NORMAL
    assert recreated_user.apple_sub == "apple-deleted-user"

    with Session(engine) as session:
        identities = session.scalars(
            select(UserAuthIdentity).where(
                UserAuthIdentity.provider == "apple",
                UserAuthIdentity.provider_subject == "apple-deleted-user",
            )
        ).all()

    assert len(identities) == 1
    assert identities[0].user_id == recreated_user.id


def test_send_phone_code_creates_pending_record() -> None:
    res = client.post("/api/v1/auth/phone/send-code", json={"phone": "13800138000"})

    assert res.status_code == 200
    assert res.json()["ok"] is True

    with Session(engine) as session:
        record = session.scalar(select(SmsVerificationCode).where(SmsVerificationCode.phone_e164 == "+8613800138000"))

    assert record is not None
    assert record.provider == "mock"
    assert record.status == "pending"
    assert record.code_digest


def test_aliyun_send_code_uses_uuid_when_provider_only_returns_ok(monkeypatch) -> None:
    class FakeClient:
        def send_sms_verify_code(self, _request):
            return SimpleNamespace(body=SimpleNamespace(success=True, request_id=None, code="OK"))

    class FakeModels:
        @staticmethod
        def SendSmsVerifyCodeRequest(**kwargs):
            return SimpleNamespace(**kwargs)

    monkeypatch.setattr(
        AliyunSmsAuthProvider,
        "_sdk_modules",
        lambda self: (FakeClient(), FakeModels),
    )

    result = AliyunSmsAuthProvider().send_code(
        phone_e164="+8613900000000",
        code="5678",
        out_id="send-code-1",
    )

    assert result.provider == "aliyun"
    assert result.request_id.startswith("aliyun-")


def test_aliyun_send_code_maps_frequency_error(monkeypatch) -> None:
    class FakeClient:
        def send_sms_verify_code(self, _request):
            return SimpleNamespace(
                body=SimpleNamespace(
                    success=False,
                    request_id=None,
                    code="biz.FREQUENCY",
                    message="check frequency failed",
                )
            )

    class FakeModels:
        @staticmethod
        def SendSmsVerifyCodeRequest(**kwargs):
            return SimpleNamespace(**kwargs)

    monkeypatch.setattr(
        AliyunSmsAuthProvider,
        "_sdk_modules",
        lambda self: (FakeClient(), FakeModels),
    )

    try:
        AliyunSmsAuthProvider().send_code(
            phone_e164="+8613900000000",
            code="5678",
            out_id="send-code-1",
        )
    except Exception as exc:
        assert str(exc.message) == "验证码发送过于频繁，请稍后再试"
        assert exc.status_code == 429
        assert exc.code == "PHONE_CODE_TOO_FREQUENT"
    else:
        raise AssertionError("expected frequency AppException")


def test_auth_phone_accepts_mock_code_1234() -> None:
    client.post("/api/v1/auth/phone/send-code", json={"phone": "13800138000"})

    res = client.post(
        "/api/v1/auth/phone/sign-in",
        json={"phone": "13800138000", "code": "1234"},
    )

    assert res.status_code == 200
    payload = res.json()
    assert payload["isNewUser"] is True
    assert payload["user"]["nickname"] == "辩论喵用户"

    with Session(engine) as session:
        identity = session.scalar(
            select(UserAuthIdentity).where(
                UserAuthIdentity.provider == "phone",
                UserAuthIdentity.provider_subject == "+8613800138000",
            )
        )

    assert identity is not None


def test_auth_phone_reuses_existing_identity() -> None:
    settings = get_settings()
    old_interval = settings.aliyun_sms_auth_resend_interval_seconds
    settings.aliyun_sms_auth_resend_interval_seconds = 0
    try:
        client.post("/api/v1/auth/phone/send-code", json={"phone": "13800138000"})
        first = client.post("/api/v1/auth/phone/sign-in", json={"phone": "13800138000", "code": "1234"})
        client.post("/api/v1/auth/phone/send-code", json={"phone": "13800138000"})
        second = client.post("/api/v1/auth/phone/sign-in", json={"phone": "13800138000", "code": "1234"})
    finally:
        settings.aliyun_sms_auth_resend_interval_seconds = old_interval

    assert first.status_code == 200
    assert second.status_code == 200
    assert first.json()["user"]["id"] == second.json()["user"]["id"]
    assert first.json()["isNewUser"] is True
    assert second.json()["isNewUser"] is False


def test_auth_phone_rejects_wrong_mock_code() -> None:
    client.post("/api/v1/auth/phone/send-code", json={"phone": "13800138000"})
    res = client.post("/api/v1/auth/phone/sign-in", json={"phone": "13800138000", "code": "6543"})

    assert res.status_code == 401
    assert res.json()["code"] == "PHONE_CODE_INVALID"


def test_send_phone_code_rejects_too_frequent_requests() -> None:
    first = client.post("/api/v1/auth/phone/send-code", json={"phone": "13800138000"})
    second = client.post("/api/v1/auth/phone/send-code", json={"phone": "13800138000"})

    assert first.status_code == 200
    assert second.status_code == 429
    assert second.json()["code"] == "PHONE_CODE_TOO_FREQUENT"


def test_auth_phone_rejects_expired_code() -> None:
    client.post("/api/v1/auth/phone/send-code", json={"phone": "13800138000"})
    with Session(engine) as session:
        record = session.scalar(select(SmsVerificationCode).where(SmsVerificationCode.phone_e164 == "+8613800138000"))
        record.expires_at = datetime.now(UTC) - timedelta(seconds=1)
        session.add(record)
        session.commit()

    res = client.post("/api/v1/auth/phone/sign-in", json={"phone": "13800138000", "code": "1234"})

    assert res.status_code == 401
    assert res.json()["code"] == "PHONE_CODE_EXPIRED"


def test_auth_phone_recreates_deleted_account_as_new_user() -> None:
    settings = get_settings()
    old_interval = settings.aliyun_sms_auth_resend_interval_seconds
    settings.aliyun_sms_auth_resend_interval_seconds = 0
    try:
        client.post("/api/v1/auth/phone/send-code", json={"phone": "13800138000"})
        first = client.post("/api/v1/auth/phone/sign-in", json={"phone": "13800138000", "code": "1234"})
        deleted = client.delete("/api/v1/account", headers=_headers(first.json()["access_token"]))
        client.post("/api/v1/auth/phone/send-code", json={"phone": "13800138000"})
        second = client.post("/api/v1/auth/phone/sign-in", json={"phone": "13800138000", "code": "1234"})
    finally:
        settings.aliyun_sms_auth_resend_interval_seconds = old_interval

    assert deleted.status_code == 200
    assert second.status_code == 200
    assert second.json()["isNewUser"] is True
    assert first.json()["user"]["id"] != second.json()["user"]["id"]


def test_auth_phone_respects_attempt_limit() -> None:
    client.post("/api/v1/auth/phone/send-code", json={"phone": "13800138000"})
    settings = get_settings()
    old_limit = settings.aliyun_sms_auth_max_attempts
    settings.aliyun_sms_auth_max_attempts = 2
    try:
        first = client.post("/api/v1/auth/phone/sign-in", json={"phone": "13800138000", "code": "0000"})
        second = client.post("/api/v1/auth/phone/sign-in", json={"phone": "13800138000", "code": "1111"})
        third = client.post("/api/v1/auth/phone/sign-in", json={"phone": "13800138000", "code": "1234"})
    finally:
        settings.aliyun_sms_auth_max_attempts = old_limit

    assert first.status_code == 401
    assert second.status_code == 401
    assert third.status_code == 401
    assert third.json()["code"] == "PHONE_CODE_INVALID"


def test_service_allows_correct_code_after_one_wrong_attempt() -> None:
    class SequenceProvider:
        provider_name = "mock"

        def send_code(self, *, phone_e164: str, code: str, out_id: str) -> SmsSendResult:
            assert code == "1234"
            assert out_id.startswith("sign-in-")
            return SmsSendResult(request_id="seq-1", provider=self.provider_name)

    service = SmsAuthService(provider=SequenceProvider())
    with Session(engine) as session:
        service.send_sign_in_code(session, "13800138000")

    with Session(engine) as session:
        try:
            service.verify_sign_in_code(session, "13800138000", "0000")
        except AppException as exc:
            assert exc.code == "PHONE_CODE_INVALID"
        else:
            raise AssertionError("expected invalid code on first attempt")

    with Session(engine) as session:
        result = service.verify_sign_in_code(session, "13800138000", "1234")

    assert result == "+8613800138000"


def test_legacy_provider_only_code_requires_resend() -> None:
    with Session(engine) as session:
        session.add(
            SmsVerificationCode(
                phone_e164="+8613800138000",
                request_id="legacy-request-id",
                code_digest=None,
                provider="aliyun",
                biz_type="sign_in",
                expires_at=datetime.now(UTC) + timedelta(minutes=5),
            )
        )
        session.commit()

    res = client.post("/api/v1/auth/phone/sign-in", json={"phone": "13800138000", "code": "8677"})

    assert res.status_code == 401
    assert res.json()["code"] == "PHONE_CODE_EXPIRED"


def test_aliyun_send_code_uses_explicit_code_and_out_id(monkeypatch) -> None:
    captured_request = None

    class FakeClient:
        def send_sms_verify_code(self, request):
            nonlocal captured_request
            captured_request = request
            return SimpleNamespace(
                body=SimpleNamespace(
                    success=True,
                    code="OK",
                    request_id="provider-request-id",
                )
            )

    class FakeModels:
        @staticmethod
        def SendSmsVerifyCodeRequest(**kwargs):
            return SimpleNamespace(**kwargs)

    monkeypatch.setattr(
        AliyunSmsAuthProvider,
        "_sdk_modules",
        lambda self: (FakeClient(), FakeModels),
    )

    AliyunSmsAuthProvider().send_code(
        phone_e164="+8613900000000",
        code="8677",
        out_id="sign-in-8677",
    )

    assert captured_request is not None
    assert captured_request.out_id == "sign-in-8677"
    assert captured_request.country_code == "86"
    assert captured_request.code_length == 4
    assert json.loads(captured_request.template_param)["code"] == "8677"


def test_prod_disallows_mock_sms_provider() -> None:
    try:
        Settings(app_env="prod", sms_auth_provider="mock")
    except ValidationError as exc:
        assert "生产环境禁止使用 mock" in str(exc)
    else:
        raise AssertionError("expected sms auth provider validation error")


def test_auth_apple_rejects_invalid_audience(monkeypatch) -> None:
    token, jwk_payload = _signed_apple_token(audience="com.fake.Bundle")
    settings = get_settings()
    old_env = settings.app_env
    old_insecure = settings.allow_insecure_apple_token_validation
    old_audience = settings.apple_allowed_audiences

    monkeypatch.setattr(
        "app.services.apple_auth.AppleTokenValidator._load_jwks_payload",
        lambda self: [jwk_payload],
    )
    settings.app_env = "prod"
    settings.allow_insecure_apple_token_validation = False
    settings.apple_allowed_audiences = "com.wenwan.BianLunMiao"

    try:
        res = client.post("/api/v1/auth/apple", json={"identity_token": token})
    finally:
        settings.app_env = old_env
        settings.allow_insecure_apple_token_validation = old_insecure
        settings.apple_allowed_audiences = old_audience

    assert res.status_code == 401
    assert res.json()["code"] == "APPLE_TOKEN_INVALID"


def test_auth_apple_rejects_subject_exceeding_storage_limit() -> None:
    token, _ = _signed_apple_token(subject="a" * 129)

    res = client.post("/api/v1/auth/apple", json={"identity_token": token})

    assert res.status_code == 401
    assert res.json()["code"] == "APPLE_TOKEN_INVALID"


def test_auth_apple_rejects_malformed_token() -> None:
    res = client.post("/api/v1/auth/apple", json={"identity_token": "not-a-jwt"})

    assert res.status_code == 401
    assert res.json()["code"] == "APPLE_TOKEN_INVALID"


def test_auth_apple_rejects_expired_token(monkeypatch) -> None:
    expired = datetime.now(UTC) - timedelta(minutes=5)
    token, jwk_payload = _signed_apple_token(expires_at=expired)
    settings = get_settings()
    old_env = settings.app_env
    old_insecure = settings.allow_insecure_apple_token_validation
    old_audience = settings.apple_allowed_audiences

    monkeypatch.setattr(
        "app.services.apple_auth.AppleTokenValidator._load_jwks_payload",
        lambda self: [jwk_payload],
    )
    settings.app_env = "prod"
    settings.allow_insecure_apple_token_validation = False
    settings.apple_allowed_audiences = "com.wenwan.BianLunMiao"

    try:
        res = client.post("/api/v1/auth/apple", json={"identity_token": token})
    finally:
        settings.app_env = old_env
        settings.allow_insecure_apple_token_validation = old_insecure
        settings.apple_allowed_audiences = old_audience

    assert res.status_code == 401
    assert res.json()["code"] == "APPLE_TOKEN_INVALID"


def test_rpc_debug_token_and_users_me_roundtrip() -> None:
    bundle = _rpc(
        "auth.debug_token",
        {"public_id": "U900001", "nickname": "RPC 调试用户"},
    )

    assert bundle.status_code == 200
    payload = bundle.json()
    assert payload["access_token"]

    me = _rpc("users.me.get", token=payload["access_token"])
    assert me.status_code == 200
    assert me.json()["publicId"] == "U900001"


def test_rpc_unknown_action_returns_not_found() -> None:
    res = _rpc("unknown.action")

    assert res.status_code == 404
    assert res.json()["code"] == "NOT_FOUND"
    assert res.json()["requestId"] == "rpc-test-request-id"


def test_apple_jwks_payload_uses_cache(monkeypatch) -> None:
    settings = get_settings()
    validator = __import__("app.services.apple_auth", fromlist=["AppleTokenValidator"]).AppleTokenValidator()
    validator._jwks_cache = None
    validator._jwks_cache_expires_at = 0.0

    payload = {"keys": [{"kid": "cached-kid", "kty": "RSA"}]}
    calls = {"count": 0}
    opener_calls = {"count": 0}

    class DummyResponse:
        def __enter__(self):
            return self

        def __exit__(self, exc_type, exc, tb):
            return False

        def read(self) -> bytes:
            return __import__("json").dumps(payload).encode("utf-8")

    class DummyOpener:
        def open(self, url: str, timeout: int):
            calls["count"] += 1
            assert url == settings.apple_jwks_url
            assert timeout == 5
            return DummyResponse()

    def fake_build_opener(proxy_handler, https_handler):
        opener_calls["count"] += 1
        assert proxy_handler.proxies == {}
        assert https_handler._context is not None
        return DummyOpener()

    monkeypatch.setattr("app.services.apple_auth.build_opener", fake_build_opener)

    first = validator._load_jwks_payload()
    second = validator._load_jwks_payload()

    assert first == payload["keys"]
    assert second == payload["keys"]
    assert calls["count"] == 1
    assert opener_calls["count"] == 1


def test_apple_jwks_payload_falls_back_when_fetch_fails(monkeypatch) -> None:
    services = __import__("app.services.apple_auth", fromlist=["AppleTokenValidator", "APPLE_BUILTIN_FALLBACK_JWKS"])
    settings = get_settings()
    validator = services.AppleTokenValidator()
    validator._jwks_cache = None
    validator._jwks_cache_expires_at = 0.0

    fallback_payload = {"keys": [{"kid": "fallback-kid", "kty": "RSA"}]}
    old_fallback = settings.apple_jwks_fallback_json
    settings.apple_jwks_fallback_json = __import__("json").dumps(fallback_payload)

    def fake_build_opener(proxy_handler, https_handler):
        class FailingOpener:
            def open(self, url: str, timeout: int):
                raise OSError("network down")

        return FailingOpener()

    monkeypatch.setattr("app.services.apple_auth.build_opener", fake_build_opener)

    try:
        payload = validator._load_jwks_payload()
    finally:
        settings.apple_jwks_fallback_json = old_fallback

    kids = {item["kid"] for item in payload}
    assert "fallback-kid" in kids
    assert kids.issuperset({item["kid"] for item in services.APPLE_BUILTIN_FALLBACK_JWKS["keys"]})


def test_apple_jwk_lookup_forces_refresh_when_cached_keys_miss_kid(monkeypatch) -> None:
    validator = __import__("app.services.apple_auth", fromlist=["AppleTokenValidator"]).AppleTokenValidator()
    validator._jwks_cache = [{"kid": "stale-kid", "kty": "RSA"}]
    validator._jwks_cache_expires_at = float("inf")

    _, jwk_payload = _signed_apple_token(subject="apple-refresh-user")
    calls = {"count": 0}

    def fake_fetch_remote_jwks_payload():
        calls["count"] += 1
        return {"keys": [jwk_payload]}

    monkeypatch.setattr(validator, "_fetch_remote_jwks_payload", fake_fetch_remote_jwks_payload)

    matched = validator._find_jwk({"kid": jwk_payload["kid"]})

    assert matched == jwk_payload
    assert calls["count"] == 1


def test_apple_jwks_payload_uses_builtin_fallback_when_env_missing(monkeypatch) -> None:
    services = __import__("app.services.apple_auth", fromlist=["AppleTokenValidator", "APPLE_BUILTIN_FALLBACK_JWKS"])
    settings = get_settings()
    validator = services.AppleTokenValidator()
    validator._jwks_cache = None
    validator._jwks_cache_expires_at = 0.0

    old_fallback = settings.apple_jwks_fallback_json
    settings.apple_jwks_fallback_json = None

    def fake_fetch_remote_jwks_payload():
        raise OSError("network down")

    monkeypatch.setattr(validator, "_fetch_remote_jwks_payload", fake_fetch_remote_jwks_payload)

    try:
        payload = validator._load_jwks_payload()
    finally:
        settings.apple_jwks_fallback_json = old_fallback

    assert payload == services.APPLE_BUILTIN_FALLBACK_JWKS["keys"]


def test_duplicate_pending_join_request_rejected() -> None:
    owner_token = _token("U100001", "队长A")
    applicant_token = _token("U100002", "队员B")

    team_resp = client.post(
        "/api/v1/teams",
        json={"name": "测试队", "intro": "demo"},
        headers=_headers(owner_token),
    )
    assert team_resp.status_code == 200
    team_id = team_resp.json()["id"]

    first = client.post(
        f"/api/v1/teams/{team_id}/join-requests",
        json={"personal_note": "我想加入", "reason": "训练"},
        headers=_headers(applicant_token),
    )
    assert first.status_code == 200

    second = client.post(
        f"/api/v1/teams/{team_id}/join-requests",
        json={"personal_note": "我想加入", "reason": "再试一次"},
        headers=_headers(applicant_token),
    )
    assert second.status_code == 409
    assert second.json()["code"] == "DUPLICATE_PENDING_REQUEST"


def test_match_assign_same_team_rejected() -> None:
    owner_token = _token("U100010", "赛事管理员")

    team_resp = client.post(
        "/api/v1/teams",
        json={"name": "A队", "intro": "A"},
        headers=_headers(owner_token),
    )
    team_id = team_resp.json()["id"]

    tournament_resp = client.post(
        "/api/v1/tournaments",
        json={"name": "测试赛事", "intro": "intro", "status": 0},
        headers=_headers(owner_token),
    )
    assert tournament_resp.status_code == 200
    tournament_id = tournament_resp.json()["id"]

    match_resp = client.post(
        f"/api/v1/tournaments/{tournament_id}/matches",
        json={
            "name": "第一场",
            "start_time": "2026-02-17T10:00:00Z",
            "end_time": "2026-02-17T11:30:00Z",
            "format": "3v3",
        },
        headers=_headers(owner_token),
    )
    assert match_resp.status_code == 200
    match_id = match_resp.json()["id"]

    assign_resp = client.post(
        f"/api/v1/tournaments/matches/{match_id}:assign-teams",
        json={"team_a_id": team_id, "team_b_id": team_id},
        headers=_headers(owner_token),
    )
    assert assign_resp.status_code == 409
    assert assign_resp.json()["code"] == "MATCH_TEAM_DUPLICATED"


def test_ack_message_is_idempotent() -> None:
    owner_token = _token("U100020", "队长C")
    applicant_token = _token("U100021", "队员D")

    team = client.post(
        "/api/v1/teams",
        json={"name": "通知队", "intro": "demo"},
        headers=_headers(owner_token),
    ).json()

    submit = client.post(
        f"/api/v1/teams/{team['id']}/join-requests",
        json={"personal_note": "申请", "reason": "请通过"},
        headers=_headers(applicant_token),
    )
    assert submit.status_code == 200

    messages = client.get("/api/v1/messages", headers=_headers(owner_token))
    assert messages.status_code == 200
    first_msg_id = messages.json()["items"][0]["id"]

    ack1 = client.post(f"/api/v1/messages/{first_msg_id}:ack", headers=_headers(owner_token))
    ack2 = client.post(f"/api/v1/messages/{first_msg_id}:ack", headers=_headers(owner_token))

    assert ack1.status_code == 200
    assert ack2.status_code == 200
    assert ack1.json()["isAcknowledged"] is True
    assert ack2.json()["isAcknowledged"] is True


def test_message_payload_and_join_request_list_have_required_fields() -> None:
    owner_token = _token("U100030", "队长E")
    applicant_token = _token("U100031", "队员F")

    team = client.post(
        "/api/v1/teams",
        json={"name": "契约队", "intro": "demo"},
        headers=_headers(owner_token),
    ).json()

    submit = client.post(
        f"/api/v1/teams/{team['id']}/join-requests",
        json={"personal_note": "申请加入", "reason": "训练"},
        headers=_headers(applicant_token),
    )
    assert submit.status_code == 200
    join_request_id = submit.json()["id"]

    manager_messages = client.get("/api/v1/messages", headers=_headers(owner_token))
    assert manager_messages.status_code == 200
    first_message = manager_messages.json()["items"][0]
    assert first_message["payload"]["joinRequestId"] == join_request_id
    assert first_message["payload"]["teamId"] == team["id"]

    owner_related = client.get("/api/v1/teams/join-requests", headers=_headers(owner_token))
    assert owner_related.status_code == 200
    owner_item = owner_related.json()["items"][0]
    assert owner_item["teamName"] == "契约队"
    assert owner_item["teamPublicId"] == team["publicId"]
    assert owner_item["applicantNickname"] == "队员F"
    assert owner_item["applicantPublicId"] == "U100031"

    mine = client.get("/api/v1/teams/join-requests?scope=mine", headers=_headers(applicant_token))
    assert mine.status_code == 200
    assert mine.json()["items"][0]["id"] == join_request_id


def test_approved_join_request_sets_member_display_name_and_member_can_update_it() -> None:
    owner_token = _token("U100032", "队长G")
    applicant_token = _token("U100033", "队员H")

    team = client.post(
        "/api/v1/teams",
        json={"name": "称呼队", "intro": "demo"},
        headers=_headers(owner_token),
    ).json()

    submit = client.post(
        f"/api/v1/teams/{team['id']}/join-requests",
        json={"personal_note": "小黑", "reason": "想参加训练"},
        headers=_headers(applicant_token),
    )
    assert submit.status_code == 200

    approve = client.post(
        f"/api/v1/teams/join-requests/{submit.json()['id']}:approve",
        headers=_headers(owner_token),
    )
    assert approve.status_code == 200

    team_detail = client.get(f"/api/v1/teams/{team['id']}", headers=_headers(applicant_token))
    assert team_detail.status_code == 200
    member = next(item for item in team_detail.json()["members"] if item["userId"] == approve.json()["applicantUserId"])
    assert member["displayName"] == "小黑"

    rename = client.patch(
        f"/api/v1/teams/{team['id']}/members/{member['id']}",
        json={"display_name": "一辩黑猫"},
        headers=_headers(applicant_token),
    )
    assert rename.status_code == 200
    updated_member = next(item for item in rename.json()["team"]["members"] if item["id"] == member["id"])
    assert updated_member["displayName"] == "一辩黑猫"


def test_list_tournament_matches() -> None:
    owner_token = _token("U100040", "赛事管理员2")

    tournament = client.post(
        "/api/v1/tournaments",
        json={"name": "赛程列表赛事", "intro": "intro", "status": 0},
        headers=_headers(owner_token),
    ).json()

    create_1 = client.post(
        f"/api/v1/tournaments/{tournament['id']}/matches",
        json={
            "name": "第一场",
            "start_time": "2026-02-17T10:00:00Z",
            "end_time": "2026-02-17T11:30:00Z",
            "format": "3v3",
        },
        headers=_headers(owner_token),
    )
    create_2 = client.post(
        f"/api/v1/tournaments/{tournament['id']}/matches",
        json={
            "name": "第二场",
            "start_time": "2026-02-17T12:00:00Z",
            "end_time": "2026-02-17T13:30:00Z",
            "format": "3v3",
        },
        headers=_headers(owner_token),
    )
    assert create_1.status_code == 200
    assert create_2.status_code == 200

    listed = client.get(
        f"/api/v1/tournaments/{tournament['id']}/matches",
        headers=_headers(owner_token),
    )
    assert listed.status_code == 200
    payload = listed.json()
    assert len(payload["items"]) == 2
    assert payload["items"][0]["name"] == "第一场"
    assert payload["items"][1]["name"] == "第二场"


def test_tournament_visibility_is_limited_to_creator_and_participants() -> None:
    creator_token = _token("U100041", "赛事创建者")
    participant_owner_token = _token("U100042", "参赛队长")
    participant_member_token = _token("U100043", "参赛队员")
    outsider_token = _token("U100044", "无关用户")

    host_team = client.post(
        "/api/v1/teams",
        json={"name": "主办方测试队", "intro": "host"},
        headers=_headers(creator_token),
    ).json()
    participant_team = client.post(
        "/api/v1/teams",
        json={"name": "参赛测试队", "intro": "participant"},
        headers=_headers(participant_owner_token),
    ).json()

    join_request = client.post(
        f"/api/v1/teams/{participant_team['id']}/join-requests",
        json={"personal_note": "我要参赛", "reason": "成员验证"},
        headers=_headers(participant_member_token),
    )
    assert join_request.status_code == 200

    approved = client.post(
        f"/api/v1/teams/join-requests/{join_request.json()['id']}:approve",
        headers=_headers(participant_owner_token),
    )
    assert approved.status_code == 200

    tournament = client.post(
        "/api/v1/tournaments",
        json={"name": "权限过滤赛事", "intro": "only visible to related users", "status": 0},
        headers=_headers(creator_token),
    ).json()

    match = client.post(
        f"/api/v1/tournaments/{tournament['id']}/matches",
        json={
            "name": "权限验证场次",
            "start_time": "2026-03-14T10:00:00Z",
            "end_time": "2026-03-14T11:30:00Z",
            "format": "3v3",
        },
        headers=_headers(creator_token),
    ).json()

    assigned = client.post(
        f"/api/v1/tournaments/matches/{match['id']}:assign-teams",
        json={"team_a_id": participant_team["id"], "team_b_id": host_team["id"]},
        headers=_headers(creator_token),
    )
    assert assigned.status_code == 200

    creator_list = client.get("/api/v1/tournaments", headers=_headers(creator_token))
    assert creator_list.status_code == 200
    assert any(item["id"] == tournament["id"] for item in creator_list.json()["items"])

    participant_list = client.get("/api/v1/tournaments", headers=_headers(participant_member_token))
    assert participant_list.status_code == 200
    assert any(item["id"] == tournament["id"] for item in participant_list.json()["items"])

    participant_detail = client.get(
        f"/api/v1/tournaments/{tournament['id']}",
        headers=_headers(participant_member_token),
    )
    assert participant_detail.status_code == 200

    participant_matches = client.get(
        f"/api/v1/tournaments/{tournament['id']}/matches",
        headers=_headers(participant_member_token),
    )
    assert participant_matches.status_code == 200
    assert len(participant_matches.json()["items"]) == 1

    outsider_list = client.get("/api/v1/tournaments", headers=_headers(outsider_token))
    assert outsider_list.status_code == 200
    assert all(item["id"] != tournament["id"] for item in outsider_list.json()["items"])

    outsider_detail = client.get(
        f"/api/v1/tournaments/{tournament['id']}",
        headers=_headers(outsider_token),
    )
    assert outsider_detail.status_code == 404

    outsider_matches = client.get(
        f"/api/v1/tournaments/{tournament['id']}/matches",
        headers=_headers(outsider_token),
    )
    assert outsider_matches.status_code == 404


def test_delete_account_marks_deleted_and_blocks_me() -> None:
    token, jwk_payload = _signed_apple_token(subject="apple-delete-user")

    with patch(
        "app.services.apple_auth.AppleTokenValidator._load_jwks_payload",
        lambda self: [jwk_payload],
    ):
        signed_in = client.post(
            "/api/v1/auth/apple",
            json={"identity_token": token, "first_name": "删", "last_name": "除"},
        )
    assert signed_in.status_code == 200
    bundle = signed_in.json()
    token = bundle["access_token"]

    deleted = client.delete("/api/v1/account", headers=_headers(token))
    assert deleted.status_code == 200
    payload = deleted.json()
    assert payload["ok"] is True
    assert payload["status"] == "deleted"
    assert payload["deletedAt"]

    me = client.get("/api/v1/users/me", headers=_headers(token))
    assert me.status_code == 403
    assert me.json()["code"] == "ACCOUNT_DELETED"

    with Session(engine) as session:
        user = session.scalar(select(User).where(User.id == bundle["user"]["id"]))

    assert user is not None
    assert user.status == UserStatus.DELETED
    assert user.apple_sub is None

    with Session(engine) as session:
        identities = session.scalars(select(UserAuthIdentity).where(UserAuthIdentity.user_id == user.id)).all()

    assert identities == []


def test_delete_account_revokes_refresh_token() -> None:
    bundle = _debug_bundle("U100048", "删除用户B")

    deleted = client.delete("/api/v1/account", headers=_headers(bundle["access_token"]))
    assert deleted.status_code == 200

    refreshed = client.post(
        "/api/v1/auth/refresh",
        json={"refresh_token": bundle["refresh_token"]},
    )
    assert refreshed.status_code == 401
    assert refreshed.json()["code"] == "INVALID_TOKEN"


def test_media_upload_token_requires_storage_config() -> None:
    token = _token("U100050", "上传用户A")
    settings = get_settings()
    old_backend = settings.media_backend
    old_bucket = settings.oss_bucket
    old_ak = settings.oss_access_key_id
    old_sk = settings.oss_access_key_secret

    settings.media_backend = "oss"
    settings.oss_bucket = None
    settings.oss_access_key_id = None
    settings.oss_access_key_secret = None
    try:
        res = client.post("/api/v1/media/avatar-upload-token", headers=_headers(token))
    finally:
        settings.media_backend = old_backend
        settings.oss_bucket = old_bucket
        settings.oss_access_key_id = old_ak
        settings.oss_access_key_secret = old_sk

    assert res.status_code == 500
    assert res.json()["code"] == "MEDIA_STORAGE_NOT_CONFIGURED"


def test_media_upload_token_success_shape() -> None:
    token = _token("U100051", "上传用户B")
    settings = get_settings()
    old_backend = settings.media_backend
    old_bucket = settings.oss_bucket
    old_endpoint = settings.oss_endpoint
    old_ak = settings.oss_access_key_id
    old_sk = settings.oss_access_key_secret
    old_security_token = settings.oss_security_token
    old_prefix = settings.oss_env_prefix
    old_public_base = settings.oss_public_base_url

    settings.media_backend = "oss"
    settings.oss_bucket = "bianlunmiao-assets-test"
    settings.oss_endpoint = "oss-cn-hangzhou.aliyuncs.com"
    settings.oss_access_key_id = "test-ak"
    settings.oss_access_key_secret = "test-sk"
    settings.oss_security_token = None
    settings.oss_env_prefix = "stg"
    settings.oss_public_base_url = "https://bianlunmiao-assets-test.oss-cn-hangzhou.aliyuncs.com"

    try:
        res = client.post("/api/v1/media/avatar-upload-token", headers=_headers(token))
    finally:
        settings.media_backend = old_backend
        settings.oss_bucket = old_bucket
        settings.oss_endpoint = old_endpoint
        settings.oss_access_key_id = old_ak
        settings.oss_access_key_secret = old_sk
        settings.oss_security_token = old_security_token
        settings.oss_env_prefix = old_prefix
        settings.oss_public_base_url = old_public_base

    assert res.status_code == 200
    payload = res.json()
    assert payload["provider"] == "oss"
    assert payload["method"] == "PUT"
    assert payload["uploadHeaders"]["Content-Type"] == "image/jpeg"
    assert payload["objectKey"].startswith("stg/avatars/")
    assert payload["uploadUrl"].startswith("https://bianlunmiao-assets-test.oss-cn-hangzhou.aliyuncs.com/stg/avatars/")
    assert payload["publicUrl"].startswith("https://bianlunmiao-assets-test.oss-cn-hangzhou.aliyuncs.com/stg/avatars/")


def test_media_upload_token_includes_security_token_when_configured() -> None:
    token = _token("U100052", "上传用户C")
    settings = get_settings()
    old_backend = settings.media_backend
    old_bucket = settings.oss_bucket
    old_endpoint = settings.oss_endpoint
    old_ak = settings.oss_access_key_id
    old_sk = settings.oss_access_key_secret
    old_security_token = settings.oss_security_token
    old_prefix = settings.oss_env_prefix

    settings.media_backend = "oss"
    settings.oss_bucket = "bianlunmiao-assets-test"
    settings.oss_endpoint = "oss-cn-hangzhou.aliyuncs.com"
    settings.oss_access_key_id = "STS.test-ak"
    settings.oss_access_key_secret = "test-sk"
    settings.oss_security_token = "test-session-token"
    settings.oss_env_prefix = "stg"

    try:
        res = client.post("/api/v1/media/avatar-upload-token", headers=_headers(token))
    finally:
        settings.media_backend = old_backend
        settings.oss_bucket = old_bucket
        settings.oss_endpoint = old_endpoint
        settings.oss_access_key_id = old_ak
        settings.oss_access_key_secret = old_sk
        settings.oss_security_token = old_security_token
        settings.oss_env_prefix = old_prefix

    assert res.status_code == 200
    payload = res.json()
    assert "security-token=test-session-token" in payload["uploadUrl"]
    assert "security-token=" not in payload["publicUrl"]


def test_local_media_upload_roundtrip() -> None:
    token = _token("U100053", "上传用户D")
    settings = get_settings()
    old_backend = settings.media_backend
    old_prefix = settings.oss_env_prefix

    settings.media_backend = "local"
    settings.oss_env_prefix = "prod"
    try:
        token_res = _rpc("media.avatar_upload_token", token=token)
        assert token_res.status_code == 200
        payload = token_res.json()
        assert payload["provider"] == "local"
        assert payload["uploadUrl"].startswith("http://testserver/uploads/prod/avatars/")
        assert payload["publicUrl"].startswith("http://testserver/uploads/prod/avatars/")

        uploaded = client.put(
            payload["uploadUrl"],
            content=b"fake-image-data",
            headers={"Content-Type": "image/jpeg"},
        )
        assert uploaded.status_code == 200

        fetched = client.get(payload["publicUrl"])
        assert fetched.status_code == 200
        assert fetched.content == b"fake-image-data"
    finally:
        settings.media_backend = old_backend
        settings.oss_env_prefix = old_prefix


def test_local_media_upload_token_prefers_explicit_public_base_url() -> None:
    token = _token("U100054", "上传用户E")
    settings = get_settings()
    old_backend = settings.media_backend
    old_prefix = settings.oss_env_prefix
    old_public_base = settings.public_base_url

    settings.media_backend = "local"
    settings.oss_env_prefix = "prod"
    settings.public_base_url = "https://bianlunapi-prod-qhjiqiwcgz.cn-hangzhou.fcapp.run"
    try:
        res = client.post("/api/v1/media/avatar-upload-token", headers=_headers(token))
    finally:
        settings.media_backend = old_backend
        settings.oss_env_prefix = old_prefix
        settings.public_base_url = old_public_base

    assert res.status_code == 200
    payload = res.json()
    assert payload["uploadUrl"].startswith(
        "https://bianlunapi-prod-qhjiqiwcgz.cn-hangzhou.fcapp.run/uploads/prod/avatars/"
    )
    assert payload["publicUrl"].startswith(
        "https://bianlunapi-prod-qhjiqiwcgz.cn-hangzhou.fcapp.run/uploads/prod/avatars/"
    )


def test_local_media_upload_token_uses_forwarded_proto_and_host_in_prod() -> None:
    token = _token("U100055", "上传用户F")
    settings = get_settings()
    old_backend = settings.media_backend
    old_prefix = settings.oss_env_prefix
    old_public_base = settings.public_base_url
    old_env = settings.app_env

    settings.media_backend = "local"
    settings.oss_env_prefix = "prod"
    settings.public_base_url = None
    settings.app_env = "prod"
    try:
        res = client.post(
            "/api/v1/media/avatar-upload-token",
            headers={
                **_headers(token),
                "x-blm-public-base-url": "http://internal.fc.local",
                "x-forwarded-proto": "https",
                "x-forwarded-host": "bianlunapi-prod-qhjiqiwcgz.cn-hangzhou.fcapp.run",
            },
        )
    finally:
        settings.media_backend = old_backend
        settings.oss_env_prefix = old_prefix
        settings.public_base_url = old_public_base
        settings.app_env = old_env

    assert res.status_code == 200
    payload = res.json()
    assert payload["uploadUrl"].startswith(
        "https://bianlunapi-prod-qhjiqiwcgz.cn-hangzhou.fcapp.run/uploads/prod/avatars/"
    )
    assert payload["publicUrl"].startswith(
        "https://bianlunapi-prod-qhjiqiwcgz.cn-hangzhou.fcapp.run/uploads/prod/avatars/"
    )

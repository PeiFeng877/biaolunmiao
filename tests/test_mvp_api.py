import os
from pathlib import Path
from datetime import UTC, datetime, timedelta

from cryptography.hazmat.primitives import serialization
from cryptography.hazmat.primitives.asymmetric import rsa
from fastapi.testclient import TestClient
from jose import jwt
from jose.utils import base64url_encode

# 测试使用独立 sqlite，避免依赖本地 postgres。
os.environ.setdefault("DATABASE_URL", f"sqlite:///{Path(__file__).parent / 'test.db'}")
os.environ.setdefault("ENABLE_DEBUG_TOKEN", "true")
os.environ.setdefault("APP_ENV", "local")
os.environ.setdefault("ALLOW_INSECURE_APPLE_TOKEN_VALIDATION", "true")

from app.core.config import get_settings
from app.db.base import Base
from app.db.session import engine
from app.main import app

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
    assert payload["access_token"]
    assert payload["refresh_token"]


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
    settings = get_settings()
    validator = __import__("app.services.apple_auth", fromlist=["AppleTokenValidator"]).AppleTokenValidator()
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

    assert payload == fallback_payload["keys"]


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


def test_media_upload_token_requires_storage_config() -> None:
    token = _token("U100050", "上传用户A")
    settings = get_settings()
    old_bucket = settings.oss_bucket
    old_ak = settings.oss_access_key_id
    old_sk = settings.oss_access_key_secret

    settings.oss_bucket = None
    settings.oss_access_key_id = None
    settings.oss_access_key_secret = None
    try:
        res = client.post("/api/v1/media/avatar-upload-token", headers=_headers(token))
    finally:
        settings.oss_bucket = old_bucket
        settings.oss_access_key_id = old_ak
        settings.oss_access_key_secret = old_sk

    assert res.status_code == 500
    assert res.json()["code"] == "MEDIA_STORAGE_NOT_CONFIGURED"


def test_media_upload_token_success_shape() -> None:
    token = _token("U100051", "上传用户B")
    settings = get_settings()
    old_bucket = settings.oss_bucket
    old_endpoint = settings.oss_endpoint
    old_ak = settings.oss_access_key_id
    old_sk = settings.oss_access_key_secret
    old_prefix = settings.oss_env_prefix
    old_public_base = settings.oss_public_base_url

    settings.oss_bucket = "bianlunmiao-assets-test"
    settings.oss_endpoint = "oss-cn-hangzhou.aliyuncs.com"
    settings.oss_access_key_id = "test-ak"
    settings.oss_access_key_secret = "test-sk"
    settings.oss_env_prefix = "stg"
    settings.oss_public_base_url = "https://bianlunmiao-assets-test.oss-cn-hangzhou.aliyuncs.com"

    try:
        res = client.post("/api/v1/media/avatar-upload-token", headers=_headers(token))
    finally:
        settings.oss_bucket = old_bucket
        settings.oss_endpoint = old_endpoint
        settings.oss_access_key_id = old_ak
        settings.oss_access_key_secret = old_sk
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

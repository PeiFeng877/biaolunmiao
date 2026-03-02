from json import JSONDecodeError
from json import load as json_load
from time import time
from urllib.error import URLError
from urllib.request import urlopen

from fastapi import APIRouter, Depends
from jose import JWTError, jwt
from sqlalchemy import select
from sqlalchemy.orm import Session

from app.api.v1.serializers import user_out
from app.core.config import get_settings
from app.core.error_codes import ErrorCode
from app.core.exceptions import AppException
from app.core.security import (
    create_access_token,
    create_refresh_token,
    decode_token,
    require_token_type,
)
from app.db.session import get_db
from app.models import RefreshToken, User
from app.schemas.auth import AppleAuthIn, DebugTokenIn, RefreshTokenIn, TestPhoneAuthIn, TokenBundleOut
from app.services.common import generate_public_id

router = APIRouter(prefix="/auth", tags=["auth"])
APPLE_IDENTITY_ISSUER = "https://appleid.apple.com"
APPLE_JWKS_URL = "https://appleid.apple.com/auth/keys"
_cached_apple_keys: dict[str, object] | None = None
_cached_apple_keys_at: float = 0.0


def _issue_tokens(db: Session, user: User) -> dict:
    access_token, access_exp = create_access_token(user.id)
    refresh_token, refresh_exp, refresh_jti = create_refresh_token(user.id)

    db.add(
        RefreshToken(
            user_id=user.id,
            token_jti=refresh_jti,
            expires_at=refresh_exp,
        )
    )
    db.commit()

    return {
        "access_token": access_token,
        "refresh_token": refresh_token,
        "token_type": "bearer",
        "access_expires_at": access_exp,
        "refresh_expires_at": refresh_exp,
        "user": user_out(user),
    }


def _fetch_apple_jwks(cache_ttl_seconds: int) -> list[dict]:
    global _cached_apple_keys, _cached_apple_keys_at
    now = time()
    if _cached_apple_keys is not None and now - _cached_apple_keys_at < cache_ttl_seconds:
        keys = _cached_apple_keys.get("keys", [])
        return keys if isinstance(keys, list) else []

    try:
        with urlopen(APPLE_JWKS_URL, timeout=5) as response:  # noqa: S310
            payload = json_load(response)
    except (URLError, TimeoutError, JSONDecodeError) as exc:
        raise AppException(ErrorCode.APPLE_TOKEN_INVALID, f"Apple 公钥拉取失败: {exc}", 400) from exc

    if not isinstance(payload, dict):
        raise AppException(ErrorCode.APPLE_TOKEN_INVALID, "Apple 公钥响应格式非法", 400)

    _cached_apple_keys = payload
    _cached_apple_keys_at = now
    keys = payload.get("keys", [])
    return keys if isinstance(keys, list) else []


def _extract_apple_sub(identity_token: str) -> str:
    settings = get_settings()
    if settings.allow_insecure_apple_token_validation:
        return f"apple:{identity_token}"

    if not settings.apple_client_id:
        raise AppException(
            ErrorCode.APPLE_TOKEN_INVALID,
            "当前环境未配置 APPLE_CLIENT_ID，无法校验 Apple token",
            400,
        )

    try:
        header = jwt.get_unverified_header(identity_token)
    except JWTError as exc:
        raise AppException(ErrorCode.APPLE_TOKEN_INVALID, f"identity_token 非法: {exc}", 400) from exc

    kid = header.get("kid")
    alg = header.get("alg", "RS256")
    if not isinstance(kid, str) or not kid:
        raise AppException(ErrorCode.APPLE_TOKEN_INVALID, "identity_token 缺少 kid", 400)
    if not isinstance(alg, str) or not alg:
        raise AppException(ErrorCode.APPLE_TOKEN_INVALID, "identity_token 缺少 alg", 400)

    keys = _fetch_apple_jwks(settings.apple_keys_cache_ttl_seconds)
    key = next((candidate for candidate in keys if candidate.get("kid") == kid), None)
    if key is None:
        keys = _fetch_apple_jwks(0)
        key = next((candidate for candidate in keys if candidate.get("kid") == kid), None)
    if key is None:
        raise AppException(ErrorCode.APPLE_TOKEN_INVALID, "未匹配到 Apple 公钥", 400)

    try:
        claims = jwt.decode(
            identity_token,
            key,
            algorithms=[alg],
            audience=settings.apple_client_id,
            issuer=APPLE_IDENTITY_ISSUER,
        )
    except JWTError as exc:
        raise AppException(ErrorCode.APPLE_TOKEN_INVALID, f"Apple token 校验失败: {exc}", 400) from exc

    sub = claims.get("sub")
    if not isinstance(sub, str) or not sub:
        raise AppException(ErrorCode.APPLE_TOKEN_INVALID, "Apple token 缺少 sub", 400)
    return f"apple:{sub}"


@router.post("/apple", response_model=TokenBundleOut)
def auth_apple(payload: AppleAuthIn, db: Session = Depends(get_db)):
    identity_token = payload.identity_token.strip()
    if not identity_token:
        raise AppException(ErrorCode.APPLE_TOKEN_INVALID, "identity_token 不能为空", 400)

    apple_sub = _extract_apple_sub(identity_token)

    user = db.scalar(select(User).where(User.apple_sub == apple_sub))
    if user is None:
        nickname = (
            "".join([payload.first_name or "", payload.last_name or ""]).strip() or "辩论喵用户"
        )
        user = User(
            apple_sub=apple_sub,
            public_id=generate_public_id("U"),
            nickname=nickname,
            status=0,
        )
        db.add(user)
        db.commit()
        db.refresh(user)

    return _issue_tokens(db, user)


@router.post("/refresh", response_model=TokenBundleOut)
def refresh_token(payload: RefreshTokenIn, db: Session = Depends(get_db)):
    token_payload = decode_token(payload.refresh_token)
    require_token_type(token_payload, "refresh")

    jti = token_payload.get("jti")
    sub = token_payload.get("sub")
    if not jti or not sub:
        raise AppException(ErrorCode.INVALID_TOKEN, "refresh token 缺少 jti 或 sub", 401)

    saved = db.scalar(select(RefreshToken).where(RefreshToken.token_jti == jti))
    if saved is None or saved.revoked_at is not None:
        raise AppException(ErrorCode.INVALID_TOKEN, "refresh token 已失效", 401)

    user = db.scalar(select(User).where(User.id == sub))
    if user is None:
        raise AppException(ErrorCode.UNAUTHORIZED, "用户不存在", 401)

    return _issue_tokens(db, user)


@router.post("/debug-token", response_model=TokenBundleOut)
def create_debug_token(payload: DebugTokenIn, db: Session = Depends(get_db)):
    settings = get_settings()
    if not settings.enable_debug_token or settings.app_env == "prod":
        raise AppException(ErrorCode.DEBUG_TOKEN_DISABLED, "当前环境禁用 debug token", 403)

    public_id = (payload.public_id or generate_public_id("U")).strip()
    if not public_id:
        raise AppException(ErrorCode.VALIDATION_ERROR, "public_id 不能为空", 422)

    nickname = (payload.nickname or "").strip() or f"调试用户-{public_id[-4:]}"

    user = db.scalar(select(User).where(User.public_id == public_id))
    if user is None:
        user = User(public_id=public_id, nickname=nickname, status=0)
        db.add(user)
        db.commit()
        db.refresh(user)

    return _issue_tokens(db, user)


@router.post("/test-phone", response_model=TokenBundleOut)
def auth_test_phone(payload: TestPhoneAuthIn, db: Session = Depends(get_db)):
    settings = get_settings()
    if settings.app_env == "prod" or not settings.enable_test_phone_login:
        raise AppException(ErrorCode.TEST_LOGIN_DISABLED, "当前环境禁用测试手机号登录", 403)

    phone = payload.phone.strip()
    code = payload.code.strip()
    if not code:
        raise AppException(ErrorCode.VALIDATION_ERROR, "code 不能为空", 422)

    apple_sub = f"testphone:{phone}"
    user = db.scalar(select(User).where(User.apple_sub == apple_sub))
    nickname = (payload.nickname or "").strip() or f"测试用户-{phone[-4:]}"

    if user is None:
        user = User(
            apple_sub=apple_sub,
            public_id=generate_public_id("U"),
            nickname=nickname,
            status=0,
        )
        db.add(user)
        db.commit()
        db.refresh(user)
    elif payload.nickname is not None and payload.nickname.strip():
        user.nickname = nickname
        db.add(user)
        db.commit()
        db.refresh(user)

    return _issue_tokens(db, user)

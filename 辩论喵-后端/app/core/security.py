from datetime import datetime, timedelta
from uuid import uuid4

from jose import JWTError, jwt
from passlib.context import CryptContext

from app.core.config import get_settings
from app.core.error_codes import ErrorCode
from app.core.exceptions import AppException
from app.core.time import UTC

ALGORITHM = "HS256"
password_context = CryptContext(schemes=["pbkdf2_sha256"], deprecated="auto")


def _utc_now() -> datetime:
    return datetime.now(UTC)


def create_access_token(subject: str, *, actor: str = "user") -> tuple[str, datetime]:
    settings = get_settings()
    expires_at = _utc_now() + timedelta(minutes=settings.access_token_expire_minutes)
    payload = {
        "sub": subject,
        "exp": expires_at,
        "type": "access",
        "actor": actor,
        "jti": str(uuid4()),
    }
    return jwt.encode(payload, settings.secret_key, algorithm=ALGORITHM), expires_at


def create_refresh_token(subject: str, *, actor: str = "user") -> tuple[str, datetime, str]:
    settings = get_settings()
    expires_at = _utc_now() + timedelta(minutes=settings.refresh_token_expire_minutes)
    jti = str(uuid4())
    payload = {
        "sub": subject,
        "exp": expires_at,
        "type": "refresh",
        "actor": actor,
        "jti": jti,
    }
    return jwt.encode(payload, settings.secret_key, algorithm=ALGORITHM), expires_at, jti


def decode_token(token: str) -> dict:
    settings = get_settings()
    try:
        return jwt.decode(token, settings.secret_key, algorithms=[ALGORITHM])
    except JWTError as exc:
        raise AppException(
            code=ErrorCode.INVALID_TOKEN,
            message="Token 无效或已过期",
            status_code=401,
        ) from exc


def require_token_type(payload: dict, token_type: str) -> None:
    if payload.get("type") != token_type:
        raise AppException(
            code=ErrorCode.INVALID_TOKEN,
            message="Token 类型不匹配",
            status_code=401,
        )


def require_actor(payload: dict, actor: str) -> None:
    if payload.get("actor", "user") != actor:
        raise AppException(
            code=ErrorCode.INVALID_TOKEN,
            message="Token actor 不匹配",
            status_code=401,
        )


def hash_password(password: str) -> str:
    return password_context.hash(password)


def verify_password(plain_password: str, password_hash: str) -> bool:
    return password_context.verify(plain_password, password_hash)

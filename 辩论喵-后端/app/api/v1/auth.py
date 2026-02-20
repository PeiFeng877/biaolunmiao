from fastapi import APIRouter, Depends, Request
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
from app.schemas.auth import AppleAuthIn, DebugTokenIn, RefreshTokenIn, TokenBundleOut
from app.services.common import generate_public_id

router = APIRouter(prefix="/auth", tags=["auth"])


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


@router.post("/apple", response_model=TokenBundleOut)
def auth_apple(payload: AppleAuthIn, db: Session = Depends(get_db)):
    settings = get_settings()
    identity_token = payload.identity_token.strip()
    if not identity_token:
        raise AppException(ErrorCode.APPLE_TOKEN_INVALID, "identity_token 不能为空", 400)

    if not settings.allow_insecure_apple_token_validation:
        raise AppException(
            ErrorCode.APPLE_TOKEN_INVALID,
            "当前环境未启用 Apple token 真实校验配置",
            400,
        )

    # MVP 联调: 以 identity_token 作为可逆映射输入，后续替换为 Apple 公钥校验。
    apple_sub = f"apple:{identity_token}"

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
def create_debug_token(payload: DebugTokenIn, request: Request, db: Session = Depends(get_db)):
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

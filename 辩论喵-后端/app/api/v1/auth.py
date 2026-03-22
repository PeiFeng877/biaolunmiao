from datetime import datetime

from fastapi import APIRouter, Depends, Request
from sqlalchemy import select
from sqlalchemy.orm import Session

from app.api.deps import ensure_active_user
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
from app.core.time import UTC
from app.db.session import get_db
from app.models import RefreshToken, User, UserAuthIdentity
from app.models.entities import AuthIdentityProvider, UserStatus
from app.schemas.auth import (
    AppleAuthIn,
    DebugTokenIn,
    PhoneSendCodeIn,
    PhoneSignInIn,
    RefreshTokenIn,
    TokenBundleOut,
)
from app.schemas.common import SuccessAck
from app.services.apple_auth import validate_apple_identity_token
from app.services.common import generate_public_id
from app.services.sms_auth import SmsAuthService

router = APIRouter(prefix="/auth", tags=["auth"])


def _issue_tokens(db: Session, user: User, *, is_new_user: bool = False) -> dict:
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
        "isNewUser": is_new_user,
        "user": user_out(user),
    }


def _find_identity(db: Session, *, provider: str, subject: str) -> UserAuthIdentity | None:
    return db.scalar(
        select(UserAuthIdentity).where(
            UserAuthIdentity.provider == provider,
            UserAuthIdentity.provider_subject == subject,
        )
    )


def _find_user_by_identity(db: Session, *, provider: str, subject: str) -> User | None:
    identity = _find_identity(db, provider=provider, subject=subject)
    if identity is None:
        return None
    return db.scalar(select(User).where(User.id == identity.user_id))


def _bind_identity(
    db: Session,
    *,
    user: User,
    provider: str,
    subject: str,
    provider_display: str | None = None,
) -> None:
    identity = _find_identity(db, provider=provider, subject=subject)
    if identity is None:
        identity = UserAuthIdentity(
            user_id=user.id,
            provider=provider,
            provider_subject=subject,
            provider_display=provider_display,
            verified_at=datetime.now(UTC),
        )
    else:
        identity.user_id = user.id
        identity.provider_display = provider_display
        identity.verified_at = datetime.now(UTC)
    db.add(identity)


def _release_user_identities(db: Session, user_id: str) -> None:
    identities = db.scalars(select(UserAuthIdentity).where(UserAuthIdentity.user_id == user_id)).all()
    for identity in identities:
        db.delete(identity)


@router.post("/apple", response_model=TokenBundleOut)
def auth_apple(payload: AppleAuthIn, db: Session = Depends(get_db)):
    settings = get_settings()
    identity_token = payload.identity_token.strip()
    if not identity_token:
        raise AppException(ErrorCode.APPLE_TOKEN_INVALID, "identity_token 不能为空", 400)

    if settings.is_prod and settings.allow_insecure_apple_token_validation:
        raise AppException(
            ErrorCode.APPLE_TOKEN_INVALID,
            "生产环境禁止启用 Apple token 非安全校验",
            500,
        )

    identity = validate_apple_identity_token(identity_token)
    apple_sub = identity.sub

    user = _find_user_by_identity(db, provider=AuthIdentityProvider.APPLE, subject=apple_sub)
    if user is None:
        user = db.scalar(select(User).where(User.apple_sub == apple_sub))
        if user is not None and user.status != UserStatus.DELETED:
            _bind_identity(
                db,
                user=user,
                provider=AuthIdentityProvider.APPLE,
                subject=apple_sub,
                provider_display=apple_sub,
            )
            db.commit()
    if user is not None and user.status == UserStatus.DELETED:
        _release_user_identities(db, user.id)
        user.apple_sub = None
        db.add(user)
        db.commit()
        user = None

    is_new_user = user is None
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
        db.flush()
        _bind_identity(
            db,
            user=user,
            provider=AuthIdentityProvider.APPLE,
            subject=apple_sub,
            provider_display=apple_sub,
        )
        db.commit()
        db.refresh(user)
    else:
        ensure_active_user(user)
        user.apple_sub = apple_sub
        db.add(user)
        _bind_identity(
            db,
            user=user,
            provider=AuthIdentityProvider.APPLE,
            subject=apple_sub,
            provider_display=apple_sub,
        )
        db.commit()

    return _issue_tokens(db, user, is_new_user=is_new_user)


@router.post("/phone/send-code", response_model=SuccessAck)
def send_phone_sign_in_code(payload: PhoneSendCodeIn, db: Session = Depends(get_db)):
    SmsAuthService().send_sign_in_code(db, payload.phone)
    return SuccessAck()


@router.post("/phone/sign-in", response_model=TokenBundleOut)
def auth_phone(payload: PhoneSignInIn, db: Session = Depends(get_db)):
    phone_e164 = SmsAuthService().verify_sign_in_code(db, payload.phone, payload.code)
    user = _find_user_by_identity(db, provider=AuthIdentityProvider.PHONE, subject=phone_e164)

    if user is not None and user.status == UserStatus.DELETED:
        _release_user_identities(db, user.id)
        user.apple_sub = None
        db.add(user)
        db.commit()
        user = None

    is_new_user = user is None
    if user is None:
        user = User(
            public_id=generate_public_id("U"),
            nickname="辩论喵用户",
            status=0,
        )
        db.add(user)
        db.flush()
        _bind_identity(
            db,
            user=user,
            provider=AuthIdentityProvider.PHONE,
            subject=phone_e164,
            provider_display=phone_e164,
        )
        db.commit()
        db.refresh(user)
    else:
        ensure_active_user(user)
        _bind_identity(
            db,
            user=user,
            provider=AuthIdentityProvider.PHONE,
            subject=phone_e164,
            provider_display=phone_e164,
        )
        db.commit()

    return _issue_tokens(db, user, is_new_user=is_new_user)


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
    if user.status == UserStatus.DELETED:
        saved.revoked_at = saved.revoked_at or datetime.now(UTC)
        db.add(saved)
        db.commit()
        raise AppException(ErrorCode.ACCOUNT_DELETED, "该账号已删除，当前不支持恢复。", 403)

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
    else:
        ensure_active_user(user)

    return _issue_tokens(db, user)

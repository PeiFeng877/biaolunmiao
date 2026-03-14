from fastapi import Depends
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer
from sqlalchemy import select
from sqlalchemy.orm import Session

from app.core.error_codes import ErrorCode
from app.core.exceptions import AppException
from app.core.security import decode_token, require_token_type
from app.db.session import get_db
from app.models import User
from app.models.entities import UserStatus

bearer_scheme = HTTPBearer(auto_error=False)


def ensure_active_user(user: User) -> User:
    if user.status == UserStatus.DELETED:
        raise AppException(ErrorCode.ACCOUNT_DELETED, "该账号已删除，当前不支持恢复。", 403)
    return user


def get_current_user(
    credentials: HTTPAuthorizationCredentials | None = Depends(bearer_scheme),
    db: Session = Depends(get_db),
) -> User:
    if credentials is None:
        raise AppException(ErrorCode.UNAUTHORIZED, "缺少登录凭证", 401)

    payload = decode_token(credentials.credentials)
    require_token_type(payload, "access")

    user_id = payload.get("sub")
    if not user_id:
        raise AppException(ErrorCode.INVALID_TOKEN, "Token 缺少 sub", 401)

    user = db.scalar(select(User).where(User.id == user_id))
    if user is None:
        raise AppException(ErrorCode.UNAUTHORIZED, "用户不存在", 401)
    return ensure_active_user(user)

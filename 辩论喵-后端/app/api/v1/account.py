from datetime import datetime

from fastapi import APIRouter, Depends
from sqlalchemy import select
from sqlalchemy.orm import Session

from app.api.deps import get_current_user
from app.core.time import UTC
from app.db.session import get_db
from app.models import RefreshToken, User
from app.models.entities import UserStatus
from app.schemas.account import AccountDeletionOut

router = APIRouter(prefix="/account", tags=["account"])


@router.delete("", response_model=AccountDeletionOut)
def delete_account(
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    deleted_at = datetime.now(UTC)
    current_user.status = UserStatus.DELETED
    current_user.deleted_at = deleted_at
    current_user.apple_sub = None
    db.add(current_user)

    tokens = db.scalars(select(RefreshToken).where(RefreshToken.user_id == current_user.id)).all()
    for token in tokens:
        token.revoked_at = token.revoked_at or deleted_at
        db.add(token)

    db.commit()
    db.refresh(current_user)

    return AccountDeletionOut(ok=True, status="deleted", deletedAt=deleted_at)

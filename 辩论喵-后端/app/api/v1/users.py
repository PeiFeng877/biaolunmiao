from fastapi import APIRouter, Depends, Query
from sqlalchemy import or_, select
from sqlalchemy.orm import Session

from app.api.deps import get_current_user
from app.api.v1.serializers import user_out
from app.db.session import get_db
from app.models import User
from app.schemas.user import UserOut, UserSearchItem, UserSearchOut, UserUpdateIn

router = APIRouter(prefix="/users", tags=["users"])


@router.get("/me", response_model=UserOut)
def get_me(current_user: User = Depends(get_current_user)):
    return user_out(current_user)


@router.put("/me", response_model=UserOut)
def update_me(
    payload: UserUpdateIn,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    current_user.nickname = payload.nickname.strip()
    current_user.avatar_url = payload.avatar_url
    db.add(current_user)
    db.commit()
    db.refresh(current_user)
    return user_out(current_user)


@router.get("/search", response_model=UserSearchOut)
def search_users(
    q: str = Query(default="", max_length=50),
    cursor: str | None = None,
    limit: int = Query(default=20, ge=1, le=100),
    db: Session = Depends(get_db),
):
    keyword = q.strip()
    query = select(User)
    if keyword:
        query = query.where(
            or_(
                User.public_id.ilike(f"%{keyword}%"),
                User.nickname.ilike(f"%{keyword}%"),
            )
        )
    query = query.order_by(User.created_at.desc())

    start = int(cursor or "0")
    users = db.scalars(query.offset(start).limit(limit + 1)).all()
    next_cursor = str(start + limit) if len(users) > limit else None
    users = users[:limit]

    items = [
        UserSearchItem(
            id=u.id,
            publicId=u.public_id,
            nickname=u.nickname,
            avatarUrl=u.avatar_url,
        )
        for u in users
    ]
    return UserSearchOut(items=items, nextCursor=next_cursor)

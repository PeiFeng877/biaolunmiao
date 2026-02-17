from datetime import UTC, datetime

from fastapi import APIRouter, Depends, Query
from sqlalchemy import select
from sqlalchemy.orm import Session

from app.api.deps import get_current_user
from app.core.error_codes import ErrorCode
from app.core.exceptions import AppException
from app.db.session import get_db
from app.models import Message, User, UserMessageStatus
from app.schemas.message import MessageListOut, MessageOut

router = APIRouter(prefix="/messages", tags=["messages"])


def _out(db: Session, msg: Message, user_id: str) -> MessageOut:
    status = db.scalar(
        select(UserMessageStatus).where(
            UserMessageStatus.message_id == msg.id,
            UserMessageStatus.user_id == user_id,
        )
    )
    return MessageOut(
        id=msg.id,
        kind=msg.kind,
        title=msg.title,
        subtitle=msg.subtitle,
        createdAt=msg.created_at,
        relatedMatchId=msg.related_match_id,
        isAcknowledged=(status.is_acknowledged if status else False),
        payload=msg.payload,
    )


@router.get("", response_model=MessageListOut)
def list_messages(
    cursor: str | None = None,
    limit: int = Query(default=20, ge=1, le=100),
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    start = int(cursor or "0")
    rows = db.scalars(
        select(Message)
        .where(Message.recipient_user_id == current_user.id)
        .order_by(Message.created_at.desc())
        .offset(start)
        .limit(limit + 1)
    ).all()
    next_cursor = str(start + limit) if len(rows) > limit else None
    rows = rows[:limit]

    return MessageListOut(
        items=[_out(db, msg, current_user.id) for msg in rows], nextCursor=next_cursor
    )


@router.post("/{message_id}:ack", response_model=MessageOut)
def ack_message(
    message_id: str,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    msg = db.scalar(
        select(Message).where(
            Message.id == message_id, Message.recipient_user_id == current_user.id
        )
    )
    if msg is None:
        raise AppException(ErrorCode.NOT_FOUND, "消息不存在", 404)

    status = db.scalar(
        select(UserMessageStatus).where(
            UserMessageStatus.message_id == message_id,
            UserMessageStatus.user_id == current_user.id,
        )
    )
    if status is None:
        status = UserMessageStatus(
            message_id=message_id,
            user_id=current_user.id,
            is_acknowledged=True,
            acknowledged_at=datetime.now(UTC),
        )
    else:
        status.is_acknowledged = True
        status.acknowledged_at = datetime.now(UTC)

    db.add(status)
    db.commit()
    return _out(db, msg, current_user.id)

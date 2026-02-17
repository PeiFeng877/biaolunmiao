from datetime import datetime

from pydantic import BaseModel


class MessageOut(BaseModel):
    id: str
    kind: str
    title: str
    subtitle: str
    createdAt: datetime
    relatedMatchId: str | None = None
    isAcknowledged: bool
    payload: dict | None = None


class MessageListOut(BaseModel):
    items: list[MessageOut]
    nextCursor: str | None = None

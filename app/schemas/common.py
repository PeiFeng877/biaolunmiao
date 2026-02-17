from datetime import datetime

from pydantic import BaseModel, Field


class CursorPage(BaseModel):
    items: list
    nextCursor: str | None = None


class ErrorBody(BaseModel):
    code: str
    message: str
    requestId: str
    details: dict | None = None


class SuccessAck(BaseModel):
    ok: bool = True
    timestamp: datetime = Field(default_factory=datetime.utcnow)

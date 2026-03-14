from datetime import datetime

from pydantic import BaseModel


class AccountDeletionOut(BaseModel):
    ok: bool = True
    status: str
    deletedAt: datetime

from datetime import datetime

from pydantic import BaseModel, Field

from app.schemas.user import UserOut


class AppleAuthIn(BaseModel):
    identity_token: str = Field(min_length=1)
    first_name: str | None = None
    last_name: str | None = None


class RefreshTokenIn(BaseModel):
    refresh_token: str


class DebugTokenIn(BaseModel):
    public_id: str | None = Field(default=None, min_length=1, max_length=20)
    nickname: str | None = Field(default=None, min_length=1, max_length=50)


class TokenBundleOut(BaseModel):
    access_token: str
    refresh_token: str
    token_type: str = "bearer"
    access_expires_at: datetime
    refresh_expires_at: datetime
    user: UserOut

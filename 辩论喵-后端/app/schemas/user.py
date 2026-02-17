from pydantic import BaseModel, Field


class UserOut(BaseModel):
    id: str
    publicId: str
    nickname: str
    avatarUrl: str | None = None
    status: int


class UserUpdateIn(BaseModel):
    nickname: str = Field(min_length=1, max_length=50)
    avatar_url: str | None = Field(default=None, max_length=255)


class UserSearchItem(BaseModel):
    id: str
    publicId: str
    nickname: str
    avatarUrl: str | None = None


class UserSearchOut(BaseModel):
    items: list[UserSearchItem]
    nextCursor: str | None = None

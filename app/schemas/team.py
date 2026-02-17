from datetime import datetime

from pydantic import BaseModel, Field


class TeamMemberOut(BaseModel):
    id: str
    teamId: str
    userId: str
    role: int
    joinTime: datetime
    nickname: str
    publicId: str


class TeamOut(BaseModel):
    id: str
    publicId: str
    name: str
    intro: str | None = None
    avatarUrl: str | None = None
    ownerId: str
    status: int
    members: list[TeamMemberOut] = []


class TeamCreateIn(BaseModel):
    name: str = Field(min_length=1, max_length=50)
    intro: str | None = Field(default=None, max_length=500)
    avatar_url: str | None = Field(default=None, max_length=255)


class TeamUpdateIn(BaseModel):
    name: str = Field(min_length=1, max_length=50)
    intro: str | None = Field(default=None, max_length=500)
    avatar_url: str | None = Field(default=None, max_length=255)


class TeamListOut(BaseModel):
    items: list[TeamOut]
    nextCursor: str | None = None


class JoinRequestCreateIn(BaseModel):
    personal_note: str = Field(min_length=1, max_length=100)
    reason: str | None = None


class JoinRequestOut(BaseModel):
    id: str
    teamId: str
    teamPublicId: str
    teamName: str
    applicantUserId: str
    applicantPublicId: str
    applicantNickname: str
    personalNote: str
    reason: str | None = None
    status: str
    createdAt: datetime
    reviewedAt: datetime | None = None
    reviewedByUserId: str | None = None
    reviewedByNickname: str | None = None


class JoinRequestListOut(BaseModel):
    items: list[JoinRequestOut]
    nextCursor: str | None = None


class TransferOwnerIn(BaseModel):
    memberId: str


class TeamActionOut(BaseModel):
    team: TeamOut

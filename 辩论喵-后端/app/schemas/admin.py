from datetime import date, datetime

from pydantic import BaseModel, Field

from app.schemas.team import TeamMemberOut
from app.schemas.tournament import MatchOut, TournamentParticipantOut


class AdminOut(BaseModel):
    id: str
    email: str
    displayName: str
    role: str
    status: int
    lastLoginAt: datetime | None = None
    createdAt: datetime
    updatedAt: datetime


class AdminLoginIn(BaseModel):
    email: str = Field(min_length=3, max_length=255)
    password: str = Field(min_length=8, max_length=255)


class AdminRefreshTokenIn(BaseModel):
    refreshToken: str = Field(min_length=1)


class AdminLogoutOut(BaseModel):
    ok: bool


class AdminTokenBundleOut(BaseModel):
    accessToken: str
    refreshToken: str
    tokenType: str = "bearer"
    accessTokenExpiresAt: datetime
    refreshTokenExpiresAt: datetime
    admin: AdminOut


class OverviewUsersOut(BaseModel):
    total: int
    normal: int
    deleted: int
    banned: int


class OverviewTeamsOut(BaseModel):
    total: int
    active: int
    inactive: int


class OverviewTournamentsOut(BaseModel):
    total: int
    open: int
    ongoing: int
    ended: int


class AdminOverviewOut(BaseModel):
    users: OverviewUsersOut
    teams: OverviewTeamsOut
    tournaments: OverviewTournamentsOut
    latestActivityAt: datetime | None = None


class AdminUserListItemOut(BaseModel):
    id: str
    publicId: str
    nickname: str
    avatarUrl: str | None = None
    status: int
    deletedAt: datetime | None = None
    createdAt: datetime
    updatedAt: datetime


class AdminUserDetailOut(AdminUserListItemOut):
    appleSub: str | None = None


class AdminUserUpdateIn(BaseModel):
    nickname: str = Field(min_length=1, max_length=50)
    avatar_url: str | None = Field(default=None, max_length=255)
    status: int


class AdminUserCreateIn(BaseModel):
    public_id: str | None = Field(default=None, min_length=1, max_length=20)
    nickname: str = Field(min_length=1, max_length=50)
    avatar_url: str | None = Field(default=None, max_length=255)
    status: int = 0


class AdminUserListOut(BaseModel):
    items: list[AdminUserListItemOut]
    nextCursor: str | None = None


class AdminTeamListItemOut(BaseModel):
    id: str
    publicId: str
    name: str
    intro: str | None = None
    avatarUrl: str | None = None
    ownerId: str
    ownerNickname: str | None = None
    status: int
    memberCount: int
    createdAt: datetime
    updatedAt: datetime


class AdminTeamDetailOut(AdminTeamListItemOut):
    members: list[TeamMemberOut]


class AdminTeamUpdateIn(BaseModel):
    name: str = Field(min_length=1, max_length=50)
    intro: str | None = Field(default=None, max_length=500)
    avatar_url: str | None = Field(default=None, max_length=255)
    status: int


class AdminTeamCreateIn(BaseModel):
    owner_id: str = Field(min_length=1, max_length=36)
    name: str = Field(min_length=1, max_length=50)
    intro: str | None = Field(default=None, max_length=500)
    avatar_url: str | None = Field(default=None, max_length=255)
    status: int = 0


class AdminTeamListOut(BaseModel):
    items: list[AdminTeamListItemOut]
    nextCursor: str | None = None


class AdminTournamentListItemOut(BaseModel):
    id: str
    name: str
    intro: str | None = None
    coverUrl: str | None = None
    creatorId: str
    creatorNickname: str | None = None
    status: int
    startDate: date | None = None
    endDate: date | None = None
    participantCount: int
    matchCount: int
    createdAt: datetime
    updatedAt: datetime


class AdminTournamentDetailOut(AdminTournamentListItemOut):
    participants: list[TournamentParticipantOut]
    matches: list[MatchOut]


class AdminTournamentUpdateIn(BaseModel):
    name: str = Field(min_length=1, max_length=100)
    intro: str | None = None
    cover_url: str | None = Field(default=None, max_length=255)
    status: int
    start_date: date | None = None
    end_date: date | None = None


class AdminTournamentCreateIn(BaseModel):
    creator_id: str = Field(min_length=1, max_length=36)
    name: str = Field(min_length=1, max_length=100)
    intro: str | None = None
    cover_url: str | None = Field(default=None, max_length=255)
    status: int = 0
    start_date: date | None = None
    end_date: date | None = None


class AdminTournamentListOut(BaseModel):
    items: list[AdminTournamentListItemOut]
    nextCursor: str | None = None


class AdminMutationOut(BaseModel):
    ok: bool
    resourceId: str

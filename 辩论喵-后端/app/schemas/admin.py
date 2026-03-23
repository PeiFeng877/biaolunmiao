from __future__ import annotations

from datetime import date, datetime

from pydantic import BaseModel, Field

from app.schemas.team import JoinRequestOut, TeamMemberOut
from app.schemas.tournament import (
    MatchOut,
    MatchRosterOut,
    RosterAssignmentIn,
    TournamentParticipantOut,
)


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
    joinRequests: list[JoinRequestOut] = []


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
    participants: list[AdminTournamentParticipantOut]
    matches: list[AdminMatchOut]


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


class AdminMatchCreateIn(BaseModel):
    name: str = Field(min_length=1, max_length=100)
    topic: str | None = None
    start_time: datetime
    end_time: datetime
    location: str | None = None
    format: str = "3v3"
    opponent_team_name: str | None = None
    team_a_id: str | None = Field(default=None, min_length=1, max_length=36)
    team_b_id: str | None = Field(default=None, min_length=1, max_length=36)


class AdminMatchUpdateIn(AdminMatchCreateIn):
    pass


class AdminMatchListOut(BaseModel):
    items: list[AdminMatchOut]
    nextCursor: str | None = None


class AdminJoinRequestOut(JoinRequestOut):
    pass


class AdminJoinRequestListOut(BaseModel):
    items: list[AdminJoinRequestOut]
    nextCursor: str | None = None


class AdminTeamMemberAddIn(BaseModel):
    user_id: str = Field(min_length=1, max_length=36)


class AdminTeamMemberSetAdminIn(BaseModel):
    is_admin: bool


class AdminTransferOwnerIn(BaseModel):
    member_id: str = Field(min_length=1, max_length=36)


class AdminTeamJoinRequestListOut(BaseModel):
    items: list[AdminJoinRequestOut]
    nextCursor: str | None = None


class AdminTournamentParticipantOut(TournamentParticipantOut):
    teamName: str | None = None
    teamPublicId: str | None = None


class AdminTournamentParticipantListOut(BaseModel):
    items: list[AdminTournamentParticipantOut]
    nextCursor: str | None = None


class AdminTournamentParticipantCreateIn(BaseModel):
    team_id: str = Field(min_length=1, max_length=36)


class AdminMatchRosterOut(MatchRosterOut):
    nickname: str | None = None
    publicId: str | None = None
    teamName: str | None = None
    teamPublicId: str | None = None


class AdminMatchOut(MatchOut):
    tournamentName: str | None = None
    teamAName: str | None = None
    teamAPublicId: str | None = None
    teamBName: str | None = None
    teamBPublicId: str | None = None
    rosters: list[AdminMatchRosterOut] = []


class AdminMatchRosterUpdateIn(BaseModel):
    assignments: list[RosterAssignmentIn]


class AdminMatchResultUpdateIn(BaseModel):
    winner_team_id: str = Field(min_length=1, max_length=36)
    team_a_score: int
    team_b_score: int
    result_note: str | None = None
    best_debater_position: str | None = None


class AdminMatchStatusAdvanceIn(BaseModel):
    status: str = Field(min_length=1, max_length=20)


class AdminMutationOut(BaseModel):
    ok: bool
    resourceId: str

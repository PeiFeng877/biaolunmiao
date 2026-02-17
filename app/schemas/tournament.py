from datetime import date, datetime

from pydantic import BaseModel, Field


class TournamentCreateIn(BaseModel):
    name: str = Field(min_length=1, max_length=100)
    intro: str | None = None
    cover_url: str | None = None
    status: int = 0


class TournamentUpdateIn(BaseModel):
    name: str = Field(min_length=1, max_length=100)
    intro: str | None = None
    cover_url: str | None = None
    status: int
    start_date: date | None = None
    end_date: date | None = None


class TournamentParticipantOut(BaseModel):
    id: str
    tournamentId: str
    teamId: str
    status: str
    seed: int


class TournamentOut(BaseModel):
    id: str
    name: str
    intro: str | None = None
    coverUrl: str | None = None
    creatorId: str
    status: int
    startDate: date | None = None
    endDate: date | None = None
    participants: list[TournamentParticipantOut] = []


class TournamentListOut(BaseModel):
    items: list[TournamentOut]
    nextCursor: str | None = None


class MatchCreateIn(BaseModel):
    name: str = Field(min_length=1, max_length=100)
    topic: str | None = None
    start_time: datetime
    end_time: datetime
    location: str | None = None
    format: str = "3v3"
    opponent_team_name: str | None = None


class MatchUpdateIn(BaseModel):
    name: str = Field(min_length=1, max_length=100)
    topic: str | None = None
    start_time: datetime
    end_time: datetime
    location: str | None = None
    format: str
    opponent_team_name: str | None = None


class MatchAssignTeamsIn(BaseModel):
    team_a_id: str | None = None
    team_b_id: str | None = None


class RosterAssignmentIn(BaseModel):
    user_id: str
    position: str


class MatchRosterUpdateIn(BaseModel):
    assignments: list[RosterAssignmentIn]


class MatchStatusAdvanceIn(BaseModel):
    status: str


class MatchResultUpdateIn(BaseModel):
    winner_team_id: str
    team_a_score: int
    team_b_score: int
    result_note: str | None = None
    best_debater_position: str | None = None


class MatchRosterOut(BaseModel):
    id: str
    matchId: str
    teamId: str
    userId: str
    position: str
    status: int


class MatchOut(BaseModel):
    id: str
    tournamentId: str
    name: str
    topic: str | None = None
    startTime: datetime
    endTime: datetime
    location: str | None = None
    opponentTeamName: str | None = None
    teamAId: str | None = None
    teamBId: str | None = None
    format: str
    status: str
    winnerTeamId: str | None = None
    teamAScore: int | None = None
    teamBScore: int | None = None
    resultRecordedAt: datetime | None = None
    resultNote: str | None = None
    bestDebaterPosition: str | None = None
    rosters: list[MatchRosterOut] = []


class MatchListOut(BaseModel):
    items: list[MatchOut]
    nextCursor: str | None = None

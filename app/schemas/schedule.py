from datetime import datetime

from pydantic import BaseModel, Field


class ScheduleSourceCreateIn(BaseModel):
    kind: str
    target_id: str | None = None
    name: str = Field(min_length=1, max_length=100)


class ScheduleSourceUpdateIn(BaseModel):
    is_enabled: bool


class ScheduleSourceOut(BaseModel):
    id: str
    kind: str
    targetId: str | None = None
    name: str
    isEnabled: bool


class ScheduleOut(BaseModel):
    items: list
    nextCursor: str | None = None


class ScheduleItemOut(BaseModel):
    matchId: str
    tournamentId: str
    matchName: str
    startTime: datetime
    endTime: datetime
    location: str | None = None
    sourceKind: str
    sourceTargetId: str | None = None

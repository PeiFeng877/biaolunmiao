from __future__ import annotations

from datetime import datetime
from enum import IntEnum
from uuid import uuid4

from sqlalchemy import (
    JSON,
    Boolean,
    Date,
    DateTime,
    ForeignKey,
    Integer,
    SmallInteger,
    String,
    Text,
    UniqueConstraint,
)
from sqlalchemy.orm import Mapped, mapped_column

from app.core.enums import StrEnum
from app.core.time import UTC
from app.db.base import Base


class UserStatus(IntEnum):
    NORMAL = 0
    DELETED = 1
    BANNED = 2


class TeamRole(IntEnum):
    MEMBER = 0
    ADMIN = 1
    OWNER = 2


class TeamJoinRequestStatus(StrEnum):
    PENDING = "pending"
    APPROVED = "approved"
    REJECTED = "rejected"


class TournamentStatus(IntEnum):
    OPEN = 0
    ONGOING = 1
    ENDED = 2


class TournamentParticipantStatus(StrEnum):
    CONFIRMED = "confirmed"
    PENDING = "pending"
    REJECTED = "rejected"


class MatchFormat(StrEnum):
    F1V1 = "1v1"
    F2V2 = "2v2"
    F3V3 = "3v3"
    F4V4 = "4v4"


class MatchStatus(StrEnum):
    SCHEDULED = "scheduled"
    READY = "ready"
    ONGOING = "ongoing"
    FINISHED = "finished"


class MessageKind(StrEnum):
    APPLICATION = "application"
    NOTIFICATION = "notification"
    STATUS_CHANGE = "statusChange"


class ScheduleSourceKind(StrEnum):
    ME = "me"
    PERSON = "person"
    TEAM = "team"
    TOURNAMENT = "tournament"


class TimestampMixin:
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        default=lambda: datetime.now(UTC),
        nullable=False,
    )
    updated_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        default=lambda: datetime.now(UTC),
        onupdate=lambda: datetime.now(UTC),
        nullable=False,
    )


class User(Base, TimestampMixin):
    __tablename__ = "users"

    id: Mapped[str] = mapped_column(String(36), primary_key=True, default=lambda: str(uuid4()))
    apple_sub: Mapped[str | None] = mapped_column(String(128), unique=True)
    public_id: Mapped[str] = mapped_column(String(20), unique=True, index=True)
    nickname: Mapped[str] = mapped_column(String(50), nullable=False)
    avatar_url: Mapped[str | None] = mapped_column(String(255))
    status: Mapped[int] = mapped_column(SmallInteger, default=0, nullable=False)
    deleted_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True))


class RefreshToken(Base):
    __tablename__ = "refresh_tokens"

    id: Mapped[str] = mapped_column(String(36), primary_key=True, default=lambda: str(uuid4()))
    user_id: Mapped[str] = mapped_column(
        String(36), ForeignKey("users.id", ondelete="CASCADE"), nullable=False
    )
    token_jti: Mapped[str] = mapped_column(String(64), unique=True, nullable=False)
    expires_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), nullable=False)
    revoked_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True))
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), default=lambda: datetime.now(UTC), nullable=False
    )


class Team(Base, TimestampMixin):
    __tablename__ = "teams"

    id: Mapped[str] = mapped_column(String(36), primary_key=True, default=lambda: str(uuid4()))
    public_id: Mapped[str] = mapped_column(String(20), unique=True, index=True)
    name: Mapped[str] = mapped_column(String(50), nullable=False)
    intro: Mapped[str | None] = mapped_column(Text)
    avatar_url: Mapped[str | None] = mapped_column(String(255))
    owner_id: Mapped[str] = mapped_column(String(36), ForeignKey("users.id"), nullable=False)
    status: Mapped[int] = mapped_column(SmallInteger, default=0, nullable=False)


class TeamMember(Base, TimestampMixin):
    __tablename__ = "team_members"
    __table_args__ = (UniqueConstraint("team_id", "user_id", name="uq_team_member_team_user"),)

    id: Mapped[str] = mapped_column(String(36), primary_key=True, default=lambda: str(uuid4()))
    team_id: Mapped[str] = mapped_column(
        String(36), ForeignKey("teams.id", ondelete="CASCADE"), nullable=False
    )
    user_id: Mapped[str] = mapped_column(
        String(36), ForeignKey("users.id", ondelete="CASCADE"), nullable=False
    )
    role: Mapped[int] = mapped_column(SmallInteger, default=0, nullable=False)
    join_time: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), default=lambda: datetime.now(UTC), nullable=False
    )
    status: Mapped[int] = mapped_column(SmallInteger, default=0, nullable=False)


class TeamJoinRequest(Base, TimestampMixin):
    __tablename__ = "team_join_requests"

    id: Mapped[str] = mapped_column(String(36), primary_key=True, default=lambda: str(uuid4()))
    team_id: Mapped[str] = mapped_column(
        String(36), ForeignKey("teams.id", ondelete="CASCADE"), nullable=False
    )
    applicant_user_id: Mapped[str] = mapped_column(
        String(36), ForeignKey("users.id", ondelete="CASCADE"), nullable=False
    )
    personal_note: Mapped[str] = mapped_column(String(100), nullable=False)
    reason: Mapped[str | None] = mapped_column(Text)
    status: Mapped[str] = mapped_column(
        String(20), default=TeamJoinRequestStatus.PENDING, nullable=False
    )
    reviewed_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True))
    reviewed_by_user_id: Mapped[str | None] = mapped_column(String(36), ForeignKey("users.id"))


class Tournament(Base, TimestampMixin):
    __tablename__ = "tournaments"

    id: Mapped[str] = mapped_column(String(36), primary_key=True, default=lambda: str(uuid4()))
    name: Mapped[str] = mapped_column(String(100), nullable=False)
    intro: Mapped[str | None] = mapped_column(Text)
    cover_url: Mapped[str | None] = mapped_column(String(255))
    creator_id: Mapped[str] = mapped_column(String(36), ForeignKey("users.id"), nullable=False)
    start_date: Mapped[datetime | None] = mapped_column(Date)
    end_date: Mapped[datetime | None] = mapped_column(Date)
    status: Mapped[int] = mapped_column(SmallInteger, default=0, nullable=False)


class TournamentParticipant(Base, TimestampMixin):
    __tablename__ = "tournament_participants"
    __table_args__ = (UniqueConstraint("tournament_id", "team_id", name="uq_tournament_team"),)

    id: Mapped[str] = mapped_column(String(36), primary_key=True, default=lambda: str(uuid4()))
    tournament_id: Mapped[str] = mapped_column(
        String(36), ForeignKey("tournaments.id", ondelete="CASCADE"), nullable=False
    )
    team_id: Mapped[str] = mapped_column(
        String(36), ForeignKey("teams.id", ondelete="CASCADE"), nullable=False
    )
    status: Mapped[str] = mapped_column(
        String(20), default=TournamentParticipantStatus.CONFIRMED, nullable=False
    )
    seed: Mapped[int] = mapped_column(Integer, default=0, nullable=False)


class Match(Base, TimestampMixin):
    __tablename__ = "matches"

    id: Mapped[str] = mapped_column(String(36), primary_key=True, default=lambda: str(uuid4()))
    tournament_id: Mapped[str] = mapped_column(
        String(36), ForeignKey("tournaments.id", ondelete="CASCADE"), nullable=False
    )
    name: Mapped[str] = mapped_column(String(100), nullable=False)
    topic: Mapped[str | None] = mapped_column(String(255))
    start_time: Mapped[datetime] = mapped_column(DateTime(timezone=True), nullable=False)
    end_time: Mapped[datetime] = mapped_column(DateTime(timezone=True), nullable=False)
    location: Mapped[str | None] = mapped_column(String(255))
    opponent_team_name: Mapped[str | None] = mapped_column(String(100))

    team_a_id: Mapped[str | None] = mapped_column(String(36), ForeignKey("teams.id"))
    team_b_id: Mapped[str | None] = mapped_column(String(36), ForeignKey("teams.id"))

    format: Mapped[str] = mapped_column(String(20), default=MatchFormat.F3V3, nullable=False)
    status: Mapped[str] = mapped_column(String(20), default=MatchStatus.SCHEDULED, nullable=False)

    winner_team_id: Mapped[str | None] = mapped_column(String(36), ForeignKey("teams.id"))
    team_a_score: Mapped[int | None] = mapped_column(Integer)
    team_b_score: Mapped[int | None] = mapped_column(Integer)
    result_recorded_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True))
    result_note: Mapped[str | None] = mapped_column(Text)
    best_debater_position: Mapped[str | None] = mapped_column(String(30))


class MatchRoster(Base, TimestampMixin):
    __tablename__ = "match_rosters"
    __table_args__ = (
        UniqueConstraint("match_id", "team_id", "position", name="uq_match_team_position"),
    )

    id: Mapped[str] = mapped_column(String(36), primary_key=True, default=lambda: str(uuid4()))
    match_id: Mapped[str] = mapped_column(
        String(36), ForeignKey("matches.id", ondelete="CASCADE"), nullable=False
    )
    team_id: Mapped[str] = mapped_column(
        String(36), ForeignKey("teams.id", ondelete="CASCADE"), nullable=False
    )
    user_id: Mapped[str] = mapped_column(
        String(36), ForeignKey("users.id", ondelete="CASCADE"), nullable=False
    )
    position: Mapped[str] = mapped_column(String(20), nullable=False)
    status: Mapped[int] = mapped_column(SmallInteger, default=0, nullable=False)


class ScheduleSource(Base, TimestampMixin):
    __tablename__ = "schedule_sources"
    __table_args__ = (UniqueConstraint("user_id", "kind", "target_id", name="uq_schedule_source"),)

    id: Mapped[str] = mapped_column(String(36), primary_key=True, default=lambda: str(uuid4()))
    user_id: Mapped[str] = mapped_column(
        String(36), ForeignKey("users.id", ondelete="CASCADE"), nullable=False
    )
    kind: Mapped[str] = mapped_column(String(20), nullable=False)
    target_id: Mapped[str | None] = mapped_column(String(36))
    name: Mapped[str] = mapped_column(String(100), nullable=False)
    is_enabled: Mapped[bool] = mapped_column(Boolean, default=True, nullable=False)


class Message(Base):
    __tablename__ = "messages"

    id: Mapped[str] = mapped_column(String(36), primary_key=True, default=lambda: str(uuid4()))
    recipient_user_id: Mapped[str] = mapped_column(
        String(36), ForeignKey("users.id", ondelete="CASCADE"), nullable=False
    )
    kind: Mapped[str] = mapped_column(String(20), nullable=False)
    title: Mapped[str] = mapped_column(String(120), nullable=False)
    subtitle: Mapped[str] = mapped_column(String(255), nullable=False)
    related_match_id: Mapped[str | None] = mapped_column(String(36), ForeignKey("matches.id"))
    payload: Mapped[dict | None] = mapped_column(JSON)
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), default=lambda: datetime.now(UTC), nullable=False
    )


class UserMessageStatus(Base, TimestampMixin):
    __tablename__ = "user_message_status"
    __table_args__ = (UniqueConstraint("message_id", "user_id", name="uq_user_message_status"),)

    id: Mapped[str] = mapped_column(String(36), primary_key=True, default=lambda: str(uuid4()))
    message_id: Mapped[str] = mapped_column(
        String(36), ForeignKey("messages.id", ondelete="CASCADE"), nullable=False
    )
    user_id: Mapped[str] = mapped_column(
        String(36), ForeignKey("users.id", ondelete="CASCADE"), nullable=False
    )
    is_acknowledged: Mapped[bool] = mapped_column(Boolean, default=False, nullable=False)
    acknowledged_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True))

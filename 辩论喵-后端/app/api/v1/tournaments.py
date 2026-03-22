from datetime import datetime

from fastapi import APIRouter, Depends, Query
from sqlalchemy import and_, exists, or_, select
from sqlalchemy.orm import Session

from app.api.deps import get_current_user
from app.api.v1.serializers import match_out, tournament_participants_out
from app.core.error_codes import ErrorCode
from app.core.exceptions import AppException
from app.core.time import UTC
from app.db.session import get_db
from app.models import (
    Match,
    MatchRoster,
    Message,
    Team,
    TeamMember,
    Tournament,
    TournamentParticipant,
    User,
)
from app.schemas.tournament import (
    MatchAssignTeamsIn,
    MatchCreateIn,
    MatchListOut,
    MatchOut,
    MatchResultUpdateIn,
    MatchRosterUpdateIn,
    MatchStatusAdvanceIn,
    MatchUpdateIn,
    TournamentCreateIn,
    TournamentListOut,
    TournamentOut,
    TournamentUpdateIn,
)
from app.services.common import match_positions

router = APIRouter(prefix="/tournaments", tags=["tournaments"])


def _now() -> datetime:
    return datetime.now(UTC)


def _can_manage_tournament(db: Session, tournament_id: str, user_id: str) -> bool:
    tournament = db.scalar(select(Tournament).where(Tournament.id == tournament_id))
    return tournament is not None and tournament.creator_id == user_id


def _can_view_tournament(db: Session, tournament_id: str, user_id: str) -> bool:
    tournament = db.scalar(select(Tournament).where(Tournament.id == tournament_id))
    if tournament is None:
        return False
    if tournament.creator_id == user_id:
        return True

    is_participant_member = db.scalar(
        select(
            exists().where(
                and_(
                    TournamentParticipant.tournament_id == tournament_id,
                    TournamentParticipant.team_id == TeamMember.team_id,
                    TeamMember.user_id == user_id,
                    TeamMember.status == 0,
                )
            )
        )
    )
    if is_participant_member:
        return True

    return bool(
        db.scalar(
            select(
                exists().where(
                    and_(
                        MatchRoster.user_id == user_id,
                        MatchRoster.status == 0,
                        MatchRoster.match_id == Match.id,
                        Match.tournament_id == tournament_id,
                    )
                )
            )
        )
    )


def _team_manage_member(db: Session, team_id: str, user_id: str) -> TeamMember | None:
    return db.scalar(
        select(TeamMember).where(
            TeamMember.team_id == team_id,
            TeamMember.user_id == user_id,
            TeamMember.status == 0,
            TeamMember.role >= 1,
        )
    )


def _upsert_participant(db: Session, tournament_id: str, team_id: str) -> None:
    participant = db.scalar(
        select(TournamentParticipant).where(
            TournamentParticipant.tournament_id == tournament_id,
            TournamentParticipant.team_id == team_id,
        )
    )
    if participant:
        participant.status = "confirmed"
        db.add(participant)
        return

    seed = len(
        db.scalars(
            select(TournamentParticipant).where(
                TournamentParticipant.tournament_id == tournament_id
            )
        ).all()
    )
    db.add(
        TournamentParticipant(
            tournament_id=tournament_id,
            team_id=team_id,
            status="confirmed",
            seed=seed,
        )
    )


def _refresh_match_ready_status(db: Session, match: Match) -> None:
    if match.status in ("ongoing", "finished"):
        return

    if not match.team_a_id or not match.team_b_id:
        match.status = "scheduled"
        db.add(match)
        return

    required = len(match_positions(match.format))
    a_count = len(
        db.scalars(
            select(MatchRoster).where(
                MatchRoster.match_id == match.id,
                MatchRoster.team_id == match.team_a_id,
                MatchRoster.status == 0,
            )
        ).all()
    )
    b_count = len(
        db.scalars(
            select(MatchRoster).where(
                MatchRoster.match_id == match.id,
                MatchRoster.team_id == match.team_b_id,
                MatchRoster.status == 0,
            )
        ).all()
    )

    match.status = "ready" if a_count >= required and b_count >= required else "scheduled"
    db.add(match)


def _tournament_out(db: Session, tournament: Tournament) -> dict:
    return {
        "id": tournament.id,
        "name": tournament.name,
        "intro": tournament.intro,
        "coverUrl": tournament.cover_url,
        "creatorId": tournament.creator_id,
        "status": tournament.status,
        "startDate": tournament.start_date,
        "endDate": tournament.end_date,
        "participants": tournament_participants_out(db, tournament.id),
    }


@router.post("", response_model=TournamentOut)
def create_tournament(
    payload: TournamentCreateIn,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    tournament = Tournament(
        name=payload.name.strip(),
        intro=payload.intro,
        cover_url=payload.cover_url,
        creator_id=current_user.id,
        status=payload.status,
    )
    db.add(tournament)
    db.commit()
    db.refresh(tournament)
    return _tournament_out(db, tournament)


@router.get("", response_model=TournamentListOut)
def list_tournaments(
    status: int | None = Query(default=None),
    q: str = Query(default="", max_length=50),
    cursor: str | None = None,
    limit: int = Query(default=20, ge=1, le=100),
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    start = int(cursor or "0")
    participant_team_ids = select(TeamMember.team_id).where(
        TeamMember.user_id == current_user.id,
        TeamMember.status == 0,
    )
    roster_match_ids = select(MatchRoster.match_id).where(
        MatchRoster.user_id == current_user.id,
        MatchRoster.status == 0,
    )
    visible_tournament_ids = select(Match.tournament_id).where(
        or_(
            Match.id.in_(roster_match_ids),
            Match.team_a_id.in_(participant_team_ids),
            Match.team_b_id.in_(participant_team_ids),
        )
    )

    query = select(Tournament).where(
        or_(
            Tournament.creator_id == current_user.id,
            Tournament.id.in_(select(TournamentParticipant.tournament_id).where(TournamentParticipant.team_id.in_(participant_team_ids))),
            Tournament.id.in_(visible_tournament_ids),
        )
    )

    if status is not None:
        query = query.where(Tournament.status == status)
    keyword = q.strip()
    if keyword:
        query = query.where(Tournament.name.ilike(f"%{keyword}%"))

    query = query.order_by(Tournament.created_at.desc())
    rows = db.scalars(query.offset(start).limit(limit + 1)).all()
    next_cursor = str(start + limit) if len(rows) > limit else None
    rows = rows[:limit]

    return TournamentListOut(items=[_tournament_out(db, t) for t in rows], nextCursor=next_cursor)


@router.get("/{tournament_id}", response_model=TournamentOut)
def get_tournament(
    tournament_id: str,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    tournament = db.scalar(select(Tournament).where(Tournament.id == tournament_id))
    if tournament is None or not _can_view_tournament(db, tournament_id, current_user.id):
        raise AppException(ErrorCode.NOT_FOUND, "赛事不存在", 404)
    return _tournament_out(db, tournament)


@router.put("/{tournament_id}", response_model=TournamentOut)
def update_tournament(
    tournament_id: str,
    payload: TournamentUpdateIn,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    if not _can_manage_tournament(db, tournament_id, current_user.id):
        raise AppException(ErrorCode.FORBIDDEN, "仅赛事创建者可修改", 403)

    tournament = db.scalar(select(Tournament).where(Tournament.id == tournament_id))
    if tournament is None:
        raise AppException(ErrorCode.NOT_FOUND, "赛事不存在", 404)

    tournament.name = payload.name.strip()
    tournament.intro = payload.intro
    tournament.cover_url = payload.cover_url
    tournament.status = payload.status
    tournament.start_date = payload.start_date
    tournament.end_date = payload.end_date

    db.add(tournament)
    db.commit()
    db.refresh(tournament)
    return _tournament_out(db, tournament)


@router.post("/{tournament_id}/matches", response_model=MatchOut)
def create_match(
    tournament_id: str,
    payload: MatchCreateIn,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    if not _can_manage_tournament(db, tournament_id, current_user.id):
        raise AppException(ErrorCode.FORBIDDEN, "仅赛事创建者可创建场次", 403)

    tournament = db.scalar(select(Tournament).where(Tournament.id == tournament_id))
    if tournament is None:
        raise AppException(ErrorCode.NOT_FOUND, "赛事不存在", 404)

    match = Match(
        tournament_id=tournament_id,
        name=payload.name.strip(),
        topic=payload.topic,
        start_time=payload.start_time,
        end_time=payload.end_time,
        location=payload.location,
        format=payload.format,
        opponent_team_name=payload.opponent_team_name,
        status="scheduled",
    )
    db.add(match)
    db.commit()
    db.refresh(match)
    return match_out(db, match)


@router.get("/{tournament_id}/matches", response_model=MatchListOut)
def list_matches(
    tournament_id: str,
    cursor: str | None = None,
    limit: int = Query(default=50, ge=1, le=200),
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    if not _can_view_tournament(db, tournament_id, current_user.id):
        raise AppException(ErrorCode.NOT_FOUND, "赛事不存在", 404)

    start = int(cursor or "0")
    rows = db.scalars(
        select(Match)
        .where(Match.tournament_id == tournament_id)
        .order_by(Match.start_time.asc(), Match.created_at.asc())
        .offset(start)
        .limit(limit + 1)
    ).all()
    next_cursor = str(start + limit) if len(rows) > limit else None
    rows = rows[:limit]

    return MatchListOut(items=[match_out(db, row) for row in rows], nextCursor=next_cursor)


@router.put("/matches/{match_id}", response_model=MatchOut)
def update_match(
    match_id: str,
    payload: MatchUpdateIn,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    match = db.scalar(select(Match).where(Match.id == match_id))
    if match is None:
        raise AppException(ErrorCode.NOT_FOUND, "场次不存在", 404)
    if not _can_manage_tournament(db, match.tournament_id, current_user.id):
        raise AppException(ErrorCode.FORBIDDEN, "仅赛事创建者可修改场次", 403)

    match.name = payload.name.strip()
    match.topic = payload.topic
    match.start_time = payload.start_time
    match.end_time = payload.end_time
    match.location = payload.location
    match.format = payload.format
    match.opponent_team_name = payload.opponent_team_name
    _refresh_match_ready_status(db, match)

    db.add(match)
    db.commit()
    db.refresh(match)
    return match_out(db, match)


@router.post("/matches/{match_id}:assign-teams", response_model=MatchOut)
def assign_match_teams(
    match_id: str,
    payload: MatchAssignTeamsIn,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    match = db.scalar(select(Match).where(Match.id == match_id))
    if match is None:
        raise AppException(ErrorCode.NOT_FOUND, "场次不存在", 404)

    can_manage_tournament = _can_manage_tournament(db, match.tournament_id, current_user.id)
    can_manage_teams = any(
        [
            payload.team_a_id and _team_manage_member(db, payload.team_a_id, current_user.id),
            payload.team_b_id and _team_manage_member(db, payload.team_b_id, current_user.id),
        ]
    )

    if not can_manage_tournament and not can_manage_teams:
        raise AppException(ErrorCode.FORBIDDEN, "无权指派队伍", 403)

    if payload.team_a_id and payload.team_b_id and payload.team_a_id == payload.team_b_id:
        raise AppException(ErrorCode.MATCH_TEAM_DUPLICATED, "A/B 队不能相同", 409)

    for team_id in [payload.team_a_id, payload.team_b_id]:
        if team_id is None:
            continue
        team = db.scalar(select(Team).where(Team.id == team_id, Team.status == 0))
        if team is None:
            raise AppException(ErrorCode.NOT_FOUND, f"队伍 {team_id} 不存在", 404)
        _upsert_participant(db, match.tournament_id, team_id)

    match.team_a_id = payload.team_a_id
    match.team_b_id = payload.team_b_id

    if payload.team_a_id or payload.team_b_id:
        valid = [x for x in [payload.team_a_id, payload.team_b_id] if x is not None]
        rosters = db.scalars(select(MatchRoster).where(MatchRoster.match_id == match.id)).all()
        for roster in rosters:
            if roster.team_id not in valid:
                db.delete(roster)

    _refresh_match_ready_status(db, match)
    db.add(match)
    db.commit()
    db.refresh(match)
    return match_out(db, match)


@router.put("/matches/{match_id}/rosters/{team_id}", response_model=MatchOut)
def update_match_roster(
    match_id: str,
    team_id: str,
    payload: MatchRosterUpdateIn,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    match = db.scalar(select(Match).where(Match.id == match_id))
    if match is None:
        raise AppException(ErrorCode.NOT_FOUND, "场次不存在", 404)
    if team_id not in {match.team_a_id, match.team_b_id}:
        raise AppException(ErrorCode.NOT_FOUND, "该队伍不在本场次中", 404)

    if _team_manage_member(db, team_id, current_user.id) is None and not _can_manage_tournament(
        db, match.tournament_id, current_user.id
    ):
        raise AppException(ErrorCode.FORBIDDEN, "无权保存该队阵容", 403)

    allowed_positions = set(match_positions(match.format))
    team_members = db.scalars(
        select(TeamMember).where(TeamMember.team_id == team_id, TeamMember.status == 0)
    ).all()
    allowed_users = {m.user_id for m in team_members}

    seen_users: set[str] = set()
    seen_positions: set[str] = set()
    for a in payload.assignments:
        position = a.position.strip()
        if a.user_id not in allowed_users:
            raise AppException(ErrorCode.ROSTER_INVALID_MEMBER, "阵容成员必须属于该队", 409)
        if position not in allowed_positions:
            raise AppException(ErrorCode.ROSTER_INVALID_POSITION, "阵容辩位不合法", 409)
        if a.user_id in seen_users or position in seen_positions:
            raise AppException(ErrorCode.CONFLICT, "阵容存在重复成员或重复辩位", 409)
        seen_users.add(a.user_id)
        seen_positions.add(position)

    db.query(MatchRoster).filter(
        MatchRoster.match_id == match_id, MatchRoster.team_id == team_id
    ).delete()
    for a in payload.assignments:
        db.add(
            MatchRoster(
                match_id=match_id, team_id=team_id, user_id=a.user_id, position=a.position.strip()
            )
        )

    _refresh_match_ready_status(db, match)

    # 通知被指派队员
    for a in payload.assignments:
        db.add(
            Message(
                recipient_user_id=a.user_id,
                kind="notification",
                title=f"你被安排参加 {match.name}",
                subtitle=f"时间：{match.start_time.isoformat()}",
                related_match_id=match.id,
                payload={"matchId": match.id, "teamId": team_id},
            )
        )

    db.add(match)
    db.commit()
    db.refresh(match)
    return match_out(db, match)


@router.post("/matches/{match_id}:advance-status", response_model=MatchOut)
def advance_match_status(
    match_id: str,
    payload: MatchStatusAdvanceIn,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    match = db.scalar(select(Match).where(Match.id == match_id))
    if match is None:
        raise AppException(ErrorCode.NOT_FOUND, "场次不存在", 404)
    if not _can_manage_tournament(db, match.tournament_id, current_user.id):
        raise AppException(ErrorCode.FORBIDDEN, "仅赛事创建者可推进状态", 403)

    current = match.status
    target = payload.status
    allowed = {
        "scheduled": {"scheduled", "ready", "ongoing", "finished"},
        "ready": {"ready", "ongoing", "finished"},
        "ongoing": {"ongoing", "finished"},
        "finished": {"finished"},
    }

    if target not in allowed.get(current, set()):
        raise AppException(
            ErrorCode.MATCH_STATUS_INVALID_TRANSITION,
            f"不允许从 {current} 切换到 {target}",
            409,
        )

    match.status = target
    db.add(match)
    db.commit()
    db.refresh(match)

    # 状态变更通知
    roster_users = db.scalars(
        select(MatchRoster.user_id).where(MatchRoster.match_id == match.id)
    ).all()
    for user_id in set(roster_users):
        db.add(
            Message(
                recipient_user_id=user_id,
                kind="statusChange",
                title=f"{match.name} 状态更新",
                subtitle=f"当前状态：{match.status}",
                related_match_id=match.id,
                payload={"matchId": match.id, "status": match.status},
            )
        )
    db.commit()

    return match_out(db, match)


@router.put("/matches/{match_id}/result", response_model=MatchOut)
def update_match_result(
    match_id: str,
    payload: MatchResultUpdateIn,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    match = db.scalar(select(Match).where(Match.id == match_id))
    if match is None:
        raise AppException(ErrorCode.NOT_FOUND, "场次不存在", 404)
    if not _can_manage_tournament(db, match.tournament_id, current_user.id):
        raise AppException(ErrorCode.FORBIDDEN, "仅赛事创建者可录入赛果", 403)

    if payload.winner_team_id not in {match.team_a_id, match.team_b_id}:
        raise AppException(ErrorCode.VALIDATION_ERROR, "胜方必须是 A 队或 B 队", 400)

    match.winner_team_id = payload.winner_team_id
    match.team_a_score = payload.team_a_score
    match.team_b_score = payload.team_b_score
    match.result_note = payload.result_note
    match.best_debater_position = payload.best_debater_position
    match.result_recorded_at = _now()
    match.status = "finished"

    db.add(match)
    db.commit()
    db.refresh(match)
    return match_out(db, match)

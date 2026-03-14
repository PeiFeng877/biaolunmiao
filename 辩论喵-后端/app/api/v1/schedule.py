from datetime import datetime

from fastapi import APIRouter, Depends, Query
from sqlalchemy import or_, select
from sqlalchemy.orm import Session

from app.api.deps import get_current_user
from app.core.error_codes import ErrorCode
from app.core.exceptions import AppException
from app.db.session import get_db
from app.models import Match, MatchRoster, ScheduleSource, User
from app.schemas.schedule import (
    ScheduleItemOut,
    ScheduleOut,
    ScheduleSourceCreateIn,
    ScheduleSourceOut,
    ScheduleSourceUpdateIn,
)

router = APIRouter(prefix="/schedule", tags=["schedule"])


def _source_out(source: ScheduleSource) -> ScheduleSourceOut:
    return ScheduleSourceOut(
        id=source.id,
        kind=source.kind,
        targetId=source.target_id,
        name=source.name,
        isEnabled=source.is_enabled,
    )


@router.get("", response_model=ScheduleOut)
def list_schedule(
    from_: datetime = Query(alias="from"),
    to: datetime = Query(),
    cursor: str | None = None,
    limit: int = Query(default=50, ge=1, le=200),
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    user_sources = db.scalars(
        select(ScheduleSource).where(
            ScheduleSource.user_id == current_user.id, ScheduleSource.is_enabled
        )
    ).all()
    enabled_sources = [
        {"kind": "me", "target_id": None, "name": "我的赛事"},
        *[{"kind": s.kind, "target_id": s.target_id, "name": s.name} for s in user_sources],
    ]

    table: dict[str, dict] = {}
    for source in enabled_sources:
        kind = source["kind"]
        target_id = source["target_id"]

        query = select(Match).where(Match.start_time >= from_, Match.start_time <= to)
        if kind == "me":
            match_ids = db.scalars(
                select(MatchRoster.match_id).where(MatchRoster.user_id == current_user.id)
            ).all()
            if not match_ids:
                continue
            query = query.where(Match.id.in_(set(match_ids)))
        elif kind == "person" and target_id:
            match_ids = db.scalars(
                select(MatchRoster.match_id).where(MatchRoster.user_id == target_id)
            ).all()
            if not match_ids:
                continue
            query = query.where(Match.id.in_(set(match_ids)))
        elif kind == "team" and target_id:
            query = query.where(or_(Match.team_a_id == target_id, Match.team_b_id == target_id))
        elif kind == "tournament" and target_id:
            query = query.where(Match.tournament_id == target_id)
        else:
            continue

        rows = db.scalars(query).all()
        for row in rows:
            key = row.id
            table[key] = {
                "matchId": row.id,
                "tournamentId": row.tournament_id,
                "matchName": row.name,
                "startTime": row.start_time,
                "endTime": row.end_time,
                "location": row.location,
                "sourceKind": kind,
                "sourceTargetId": target_id,
            }

    items = sorted(table.values(), key=lambda x: (x["startTime"], x["matchId"]))
    start = int(cursor or "0")
    sliced = items[start : start + limit + 1]
    next_cursor = str(start + limit) if len(sliced) > limit else None
    sliced = sliced[:limit]

    return ScheduleOut(items=[ScheduleItemOut(**x) for x in sliced], nextCursor=next_cursor)


@router.get("/sources", response_model=list[ScheduleSourceOut])
def list_sources(current_user: User = Depends(get_current_user), db: Session = Depends(get_db)):
    rows = db.scalars(
        select(ScheduleSource)
        .where(ScheduleSource.user_id == current_user.id)
        .order_by(ScheduleSource.created_at.desc())
    ).all()
    return [_source_out(row) for row in rows]


@router.post("/sources", response_model=ScheduleSourceOut)
def create_source(
    payload: ScheduleSourceCreateIn,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    kind = payload.kind.strip()
    if kind == "me":
        raise AppException(ErrorCode.VALIDATION_ERROR, "me 来源由系统内建，不允许创建", 400)
    existing = db.scalar(
        select(ScheduleSource).where(
            ScheduleSource.user_id == current_user.id,
            ScheduleSource.kind == kind,
            ScheduleSource.target_id == payload.target_id,
        )
    )
    if existing:
        raise AppException(ErrorCode.CONFLICT, "来源已存在", 409)

    source = ScheduleSource(
        user_id=current_user.id,
        kind=kind,
        target_id=payload.target_id,
        name=payload.name.strip(),
        is_enabled=True,
    )
    db.add(source)
    db.commit()
    db.refresh(source)
    return _source_out(source)


@router.put("/sources/{source_id}", response_model=ScheduleSourceOut)
def update_source(
    source_id: str,
    payload: ScheduleSourceUpdateIn,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    source = db.scalar(
        select(ScheduleSource).where(
            ScheduleSource.id == source_id, ScheduleSource.user_id == current_user.id
        )
    )
    if source is None:
        raise AppException(ErrorCode.NOT_FOUND, "来源不存在", 404)
    source.is_enabled = payload.is_enabled
    db.add(source)
    db.commit()
    db.refresh(source)
    return _source_out(source)


@router.delete("/sources/{source_id}")
def delete_source(
    source_id: str, current_user: User = Depends(get_current_user), db: Session = Depends(get_db)
):
    source = db.scalar(
        select(ScheduleSource).where(
            ScheduleSource.id == source_id, ScheduleSource.user_id == current_user.id
        )
    )
    if source is None:
        raise AppException(ErrorCode.NOT_FOUND, "来源不存在", 404)
    db.delete(source)
    db.commit()
    return {"ok": True}

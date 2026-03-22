from datetime import datetime

from fastapi import APIRouter, Depends, Query
from sqlalchemy import and_, exists, or_, select
from sqlalchemy.orm import Session

from app.api.deps import get_current_user
from app.api.v1.serializers import team_out
from app.core.error_codes import ErrorCode
from app.core.exceptions import AppException
from app.core.time import UTC
from app.db.session import get_db
from app.models import Message, Team, TeamJoinRequest, TeamMember, User
from app.schemas.team import (
    JoinRequestCreateIn,
    JoinRequestListOut,
    JoinRequestOut,
    TeamActionOut,
    TeamCreateIn,
    TeamListOut,
    TeamOut,
    TeamUpdateIn,
    TransferOwnerIn,
)
from app.services.common import generate_public_id

router = APIRouter(prefix="/teams", tags=["teams"])


def _now() -> datetime:
    return datetime.now(UTC)


def _my_member(db: Session, team_id: str, user_id: str) -> TeamMember | None:
    return db.scalar(
        select(TeamMember).where(
            TeamMember.team_id == team_id,
            TeamMember.user_id == user_id,
            TeamMember.status == 0,
        )
    )


def _require_manage_team(db: Session, team_id: str, user_id: str) -> TeamMember:
    member = _my_member(db, team_id, user_id)
    if member is None or member.role < 1:
        raise AppException(ErrorCode.TEAM_ROLE_FORBIDDEN, "需要队长或管理员权限", 403)
    return member


def _require_owner(db: Session, team_id: str, user_id: str) -> TeamMember:
    member = _my_member(db, team_id, user_id)
    if member is None or member.role != 2:
        raise AppException(ErrorCode.TEAM_ROLE_FORBIDDEN, "仅队长可执行该操作", 403)
    return member


def _join_request_out(db: Session, req: TeamJoinRequest) -> JoinRequestOut:
    team = db.scalar(select(Team).where(Team.id == req.team_id))
    applicant = db.scalar(select(User).where(User.id == req.applicant_user_id))
    reviewer = (
        db.scalar(select(User).where(User.id == req.reviewed_by_user_id))
        if req.reviewed_by_user_id
        else None
    )
    return JoinRequestOut(
        id=req.id,
        teamId=req.team_id,
        teamPublicId=team.public_id if team else "",
        teamName=team.name if team else "未知队伍",
        applicantUserId=req.applicant_user_id,
        applicantPublicId=applicant.public_id if applicant else "",
        applicantNickname=applicant.nickname if applicant else "未知用户",
        personalNote=req.personal_note,
        reason=req.reason,
        status=req.status,
        createdAt=req.created_at,
        reviewedAt=req.reviewed_at,
        reviewedByUserId=req.reviewed_by_user_id,
        reviewedByNickname=reviewer.nickname if reviewer else None,
    )


@router.get("/join-requests", response_model=JoinRequestListOut)
def list_join_requests(
    scope: str = Query(default="related", pattern="^(related|for_review|mine)$"),
    status: str | None = Query(default=None, pattern="^(pending|approved|rejected)$"),
    cursor: str | None = None,
    limit: int = Query(default=20, ge=1, le=100),
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    start = int(cursor or "0")

    manageable_team_subquery = select(TeamMember.team_id).where(
        TeamMember.user_id == current_user.id,
        TeamMember.status == 0,
        TeamMember.role >= 1,
    )
    manageable_condition = TeamJoinRequest.team_id.in_(manageable_team_subquery)
    mine_condition = TeamJoinRequest.applicant_user_id == current_user.id

    query = select(TeamJoinRequest)
    if scope == "for_review":
        query = query.where(manageable_condition)
    elif scope == "mine":
        query = query.where(mine_condition)
    else:
        query = query.where(or_(manageable_condition, mine_condition))

    if status:
        query = query.where(TeamJoinRequest.status == status)

    rows = db.scalars(
        query.order_by(TeamJoinRequest.created_at.desc()).offset(start).limit(limit + 1)
    ).all()
    next_cursor = str(start + limit) if len(rows) > limit else None
    rows = rows[:limit]

    return JoinRequestListOut(
        items=[_join_request_out(db, row) for row in rows], nextCursor=next_cursor
    )


@router.post("", response_model=TeamOut)
def create_team(
    payload: TeamCreateIn,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    team = Team(
        public_id=generate_public_id(),
        name=payload.name.strip(),
        intro=payload.intro,
        avatar_url=payload.avatar_url,
        owner_id=current_user.id,
        status=0,
    )
    db.add(team)
    db.flush()

    db.add(
        TeamMember(
            team_id=team.id,
            user_id=current_user.id,
            role=2,
            status=0,
        )
    )
    db.commit()
    db.refresh(team)
    return team_out(db, team)


@router.get("/my", response_model=TeamListOut)
def my_teams(
    cursor: str | None = None,
    limit: int = Query(default=20, ge=1, le=100),
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    start = int(cursor or "0")

    query = (
        select(Team)
        .join(TeamMember, TeamMember.team_id == Team.id)
        .where(
            TeamMember.user_id == current_user.id,
            TeamMember.status == 0,
            Team.status == 0,
        )
        .order_by(Team.created_at.desc())
    )
    rows = db.scalars(query.offset(start).limit(limit + 1)).all()
    next_cursor = str(start + limit) if len(rows) > limit else None
    rows = rows[:limit]

    return TeamListOut(items=[team_out(db, t) for t in rows], nextCursor=next_cursor)


@router.get("/discover", response_model=TeamListOut)
def discover_teams(
    cursor: str | None = None,
    limit: int = Query(default=20, ge=1, le=100),
    q: str = Query(default="", max_length=50),
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    start = int(cursor or "0")

    membership_subquery = select(TeamMember.team_id).where(
        TeamMember.user_id == current_user.id,
        TeamMember.status == 0,
    )

    query = select(Team).where(Team.status == 0, Team.id.not_in(membership_subquery))
    keyword = q.strip()
    if keyword:
        query = query.where(
            or_(Team.name.ilike(f"%{keyword}%"), Team.public_id.ilike(f"%{keyword}%"))
        )

    query = query.order_by(Team.created_at.desc())

    rows = db.scalars(query.offset(start).limit(limit + 1)).all()
    next_cursor = str(start + limit) if len(rows) > limit else None
    rows = rows[:limit]
    return TeamListOut(
        items=[team_out(db, t, include_members=False) for t in rows], nextCursor=next_cursor
    )


@router.get("/{team_id}", response_model=TeamOut)
def get_team_detail(
    team_id: str, db: Session = Depends(get_db), _: User = Depends(get_current_user)
):
    team = db.scalar(select(Team).where(Team.id == team_id, Team.status == 0))
    if team is None:
        raise AppException(ErrorCode.NOT_FOUND, "队伍不存在", 404)
    return team_out(db, team)


@router.put("/{team_id}", response_model=TeamOut)
def update_team(
    team_id: str,
    payload: TeamUpdateIn,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    _require_manage_team(db, team_id, current_user.id)
    team = db.scalar(select(Team).where(Team.id == team_id, Team.status == 0))
    if team is None:
        raise AppException(ErrorCode.NOT_FOUND, "队伍不存在", 404)

    team.name = payload.name.strip()
    team.intro = payload.intro
    team.avatar_url = payload.avatar_url
    db.add(team)
    db.commit()
    db.refresh(team)
    return team_out(db, team)


@router.post("/{team_id}/join-requests", response_model=JoinRequestOut)
def submit_join_request(
    team_id: str,
    payload: JoinRequestCreateIn,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    team = db.scalar(select(Team).where(Team.id == team_id, Team.status == 0))
    if team is None:
        raise AppException(ErrorCode.NOT_FOUND, "队伍不存在", 404)

    if _my_member(db, team_id, current_user.id) is not None:
        raise AppException(ErrorCode.CONFLICT, "你已是该队成员", 409)

    pending_exists = db.scalar(
        select(
            exists().where(
                and_(
                    TeamJoinRequest.team_id == team_id,
                    TeamJoinRequest.applicant_user_id == current_user.id,
                    TeamJoinRequest.status == "pending",
                )
            )
        )
    )
    if pending_exists:
        raise AppException(ErrorCode.DUPLICATE_PENDING_REQUEST, "重复提交待审批申请", 409)

    req = TeamJoinRequest(
        team_id=team_id,
        applicant_user_id=current_user.id,
        personal_note=payload.personal_note.strip(),
        reason=payload.reason,
        status="pending",
    )
    db.add(req)
    db.flush()

    managers = db.scalars(
        select(TeamMember).where(
            TeamMember.team_id == team_id,
            TeamMember.status == 0,
            TeamMember.role >= 1,
        )
    ).all()
    for manager in managers:
        db.add(
            Message(
                recipient_user_id=manager.user_id,
                kind="application",
                title=f"{current_user.nickname} 申请加入 {team.name}",
                subtitle=f"备注：{req.personal_note}",
                payload={"teamId": team.id, "joinRequestId": req.id},
            )
        )

    db.commit()
    db.refresh(req)

    return _join_request_out(db, req)


@router.post("/join-requests/{request_id}:approve", response_model=JoinRequestOut)
def approve_join_request(
    request_id: str,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    req = db.scalar(select(TeamJoinRequest).where(TeamJoinRequest.id == request_id))
    if req is None:
        raise AppException(ErrorCode.NOT_FOUND, "申请不存在", 404)
    _require_manage_team(db, req.team_id, current_user.id)

    if req.status != "pending":
        raise AppException(ErrorCode.CONFLICT, "申请已处理", 409)

    if _my_member(db, req.team_id, req.applicant_user_id) is None:
        db.add(
            TeamMember(
                team_id=req.team_id,
                user_id=req.applicant_user_id,
                role=0,
                status=0,
            )
        )

    req.status = "approved"
    req.reviewed_at = _now()
    req.reviewed_by_user_id = current_user.id

    db.add(
        Message(
            recipient_user_id=req.applicant_user_id,
            kind="statusChange",
            title="入队申请已通过",
            subtitle="你提交的申请已被管理员通过",
            payload={"teamId": req.team_id, "joinRequestId": req.id, "status": "approved"},
        )
    )

    db.add(req)
    db.commit()
    db.refresh(req)

    return _join_request_out(db, req)


@router.post("/join-requests/{request_id}:reject", response_model=JoinRequestOut)
def reject_join_request(
    request_id: str,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    req = db.scalar(select(TeamJoinRequest).where(TeamJoinRequest.id == request_id))
    if req is None:
        raise AppException(ErrorCode.NOT_FOUND, "申请不存在", 404)
    _require_manage_team(db, req.team_id, current_user.id)

    if req.status != "pending":
        raise AppException(ErrorCode.CONFLICT, "申请已处理", 409)

    req.status = "rejected"
    req.reviewed_at = _now()
    req.reviewed_by_user_id = current_user.id

    db.add(
        Message(
            recipient_user_id=req.applicant_user_id,
            kind="statusChange",
            title="入队申请已拒绝",
            subtitle="你提交的申请未通过审核",
            payload={"teamId": req.team_id, "joinRequestId": req.id, "status": "rejected"},
        )
    )

    db.add(req)
    db.commit()
    db.refresh(req)

    return _join_request_out(db, req)


@router.post("/{team_id}:transfer-owner", response_model=TeamActionOut)
def transfer_owner(
    team_id: str,
    payload: TransferOwnerIn,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    _require_owner(db, team_id, current_user.id)

    team = db.scalar(select(Team).where(Team.id == team_id, Team.status == 0))
    if team is None:
        raise AppException(ErrorCode.NOT_FOUND, "队伍不存在", 404)

    target = db.scalar(
        select(TeamMember).where(TeamMember.id == payload.memberId, TeamMember.team_id == team_id)
    )
    if target is None or target.status != 0:
        raise AppException(ErrorCode.NOT_FOUND, "目标成员不存在", 404)

    current_owner = _my_member(db, team_id, current_user.id)
    if current_owner is None:
        raise AppException(ErrorCode.NOT_FOUND, "当前队长成员关系缺失", 404)

    current_owner.role = 1
    target.role = 2
    team.owner_id = target.user_id

    db.add(current_owner)
    db.add(target)
    db.add(team)
    db.commit()
    db.refresh(team)

    return TeamActionOut(team=team_out(db, team))


@router.post("/{team_id}/members/{member_id}:toggle-admin", response_model=TeamActionOut)
def toggle_admin(
    team_id: str,
    member_id: str,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    _require_owner(db, team_id, current_user.id)

    team = db.scalar(select(Team).where(Team.id == team_id, Team.status == 0))
    if team is None:
        raise AppException(ErrorCode.NOT_FOUND, "队伍不存在", 404)

    member = db.scalar(
        select(TeamMember).where(TeamMember.id == member_id, TeamMember.team_id == team_id)
    )
    if member is None or member.status != 0:
        raise AppException(ErrorCode.NOT_FOUND, "成员不存在", 404)
    if member.role == 2:
        raise AppException(ErrorCode.TEAM_OWNER_IMMUTABLE, "队长不能调整管理员状态", 409)

    member.role = 0 if member.role == 1 else 1
    db.add(member)
    db.commit()

    return TeamActionOut(team=team_out(db, team))


@router.delete("/{team_id}/members/{member_id}", response_model=TeamActionOut)
def remove_member(
    team_id: str,
    member_id: str,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    team = db.scalar(select(Team).where(Team.id == team_id, Team.status == 0))
    if team is None:
        raise AppException(ErrorCode.NOT_FOUND, "队伍不存在", 404)

    member = db.scalar(
        select(TeamMember).where(TeamMember.id == member_id, TeamMember.team_id == team_id)
    )
    if member is None or member.status != 0:
        raise AppException(ErrorCode.NOT_FOUND, "成员不存在", 404)

    requester = _my_member(db, team_id, current_user.id)
    if requester is None:
        raise AppException(ErrorCode.FORBIDDEN, "你不在该队伍中", 403)

    is_self_leave = member.user_id == current_user.id
    if is_self_leave:
        if member.role == 2:
            raise AppException(ErrorCode.TEAM_OWNER_IMMUTABLE, "队长不可直接退队，请先移交", 409)
        member.status = 1
    else:
        if requester.role < 1:
            raise AppException(ErrorCode.TEAM_ROLE_FORBIDDEN, "仅队长/管理员可移除他人", 403)
        if member.role == 2:
            raise AppException(ErrorCode.TEAM_OWNER_IMMUTABLE, "队长不可被移除", 409)
        if requester.role == 1 and member.role == 1:
            raise AppException(ErrorCode.TEAM_ROLE_FORBIDDEN, "管理员不可移除管理员", 403)
        member.status = 2

    db.add(member)
    db.commit()

    return TeamActionOut(team=team_out(db, team))


@router.post("/{team_id}:dissolve", response_model=TeamActionOut)
def dissolve_team(
    team_id: str,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    _require_owner(db, team_id, current_user.id)

    team = db.scalar(select(Team).where(Team.id == team_id, Team.status == 0))
    if team is None:
        raise AppException(ErrorCode.NOT_FOUND, "队伍不存在", 404)

    team.status = 1
    members = db.scalars(
        select(TeamMember).where(TeamMember.team_id == team_id, TeamMember.status == 0)
    ).all()
    for member in members:
        member.status = 1
        db.add(member)

    db.add(team)
    db.commit()
    return TeamActionOut(team=team_out(db, team))

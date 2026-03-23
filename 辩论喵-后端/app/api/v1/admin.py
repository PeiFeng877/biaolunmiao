from __future__ import annotations

from datetime import date, datetime
from typing import Any

from fastapi import APIRouter, Depends, Query
from sqlalchemy import func, or_, select
from sqlalchemy.orm import Session

from app.api.deps import ensure_active_admin, get_current_admin_user
from app.api.v1.serializers import match_out, team_out
from app.core.error_codes import ErrorCode
from app.core.exceptions import AppException
from app.core.security import (
    create_access_token,
    create_refresh_token,
    decode_token,
    require_actor,
    require_token_type,
    verify_password,
)
from app.core.time import UTC
from app.db.session import get_db
from app.models import (
    AdminAuditLog,
    AdminRefreshToken,
    AdminUser,
    Match,
    MatchRoster,
    Message,
    RefreshToken,
    Team,
    TeamJoinRequest,
    TeamMember,
    Tournament,
    TournamentParticipant,
    User,
    UserAuthIdentity,
)
from app.models.entities import (
    MatchStatus,
    TeamJoinRequestStatus,
    TeamRole,
    TournamentParticipantStatus,
    TournamentStatus,
    UserStatus,
)
from app.schemas.admin import (
    AdminJoinRequestOut,
    AdminLoginIn,
    AdminLogoutOut,
    AdminMatchCreateIn,
    AdminMatchListOut,
    AdminMatchOut,
    AdminMatchResultUpdateIn,
    AdminMatchRosterOut,
    AdminMatchRosterUpdateIn,
    AdminMatchStatusAdvanceIn,
    AdminMatchUpdateIn,
    AdminMutationOut,
    AdminOut,
    AdminOverviewOut,
    AdminRefreshTokenIn,
    AdminTeamCreateIn,
    AdminTeamDetailOut,
    AdminTeamJoinRequestListOut,
    AdminTeamListItemOut,
    AdminTeamListOut,
    AdminTeamMemberAddIn,
    AdminTeamMemberSetAdminIn,
    AdminTeamUpdateIn,
    AdminTokenBundleOut,
    AdminTournamentCreateIn,
    AdminTournamentDetailOut,
    AdminTournamentListItemOut,
    AdminTournamentListOut,
    AdminTournamentParticipantCreateIn,
    AdminTournamentParticipantListOut,
    AdminTournamentParticipantOut,
    AdminTournamentUpdateIn,
    AdminTransferOwnerIn,
    AdminUserCreateIn,
    AdminUserDetailOut,
    AdminUserListItemOut,
    AdminUserListOut,
    AdminUserUpdateIn,
)
from app.services.common import generate_public_id, match_positions

router = APIRouter(prefix="/admin", tags=["admin"])


def _now() -> datetime:
    return datetime.now(UTC)


def _normalize_email(email: str) -> str:
    return email.strip().lower()


def _admin_out(admin: AdminUser) -> dict[str, Any]:
    return AdminOut(
        id=admin.id,
        email=admin.email,
        displayName=admin.display_name,
        role=admin.role,
        status=admin.status,
        lastLoginAt=admin.last_login_at,
        createdAt=admin.created_at,
        updatedAt=admin.updated_at,
    ).model_dump()


def _issue_admin_tokens(db: Session, admin: AdminUser) -> dict[str, Any]:
    access_token, access_exp = create_access_token(admin.id, actor="admin")
    refresh_token, refresh_exp, refresh_jti = create_refresh_token(admin.id, actor="admin")

    db.add(
        AdminRefreshToken(
            admin_user_id=admin.id,
            token_jti=refresh_jti,
            expires_at=refresh_exp,
        )
    )
    db.commit()
    db.refresh(admin)

    return {
        "accessToken": access_token,
        "refreshToken": refresh_token,
        "tokenType": "bearer",
        "accessTokenExpiresAt": access_exp,
        "refreshTokenExpiresAt": refresh_exp,
        "admin": _admin_out(admin),
    }


def _decode_admin_refresh_token(refresh_token: str, db: Session) -> tuple[dict[str, Any], AdminRefreshToken]:
    try:
        payload = decode_token(refresh_token)
        require_token_type(payload, "refresh")
        require_actor(payload, "admin")
    except AppException as exc:
        raise AppException(
            ErrorCode.ADMIN_UNAUTHORIZED,
            "后台 refresh token 无效，请重新登录。",
            401,
        ) from exc

    jti = payload.get("jti")
    if not jti:
        raise AppException(ErrorCode.ADMIN_UNAUTHORIZED, "后台 refresh token 缺少 jti", 401)

    saved = db.scalar(select(AdminRefreshToken).where(AdminRefreshToken.token_jti == jti))
    if saved is None or saved.revoked_at is not None:
        raise AppException(ErrorCode.ADMIN_UNAUTHORIZED, "后台 refresh token 已失效", 401)

    return payload, saved


def _json_safe(value: Any) -> Any:
    if isinstance(value, datetime):
        return value.isoformat()
    if isinstance(value, date):
        return value.isoformat()
    if isinstance(value, dict):
        return {key: _json_safe(item) for key, item in value.items()}
    if isinstance(value, list):
        return [_json_safe(item) for item in value]
    return value


def _ensure_active_business_user(db: Session, user_id: str) -> User:
    user = db.scalar(select(User).where(User.id == user_id))
    if user is None:
        raise AppException(ErrorCode.NOT_FOUND, "用户不存在", 404)
    if user.status == UserStatus.DELETED:
        raise AppException(ErrorCode.CONFLICT, "已删除用户不能作为关联主体", 409)
    return user


def _unique_user_public_id(db: Session, preferred: str | None = None) -> str:
    if preferred:
        public_id = preferred.strip()
        exists = db.scalar(select(User.id).where(User.public_id == public_id))
        if exists is not None:
            raise AppException(ErrorCode.CONFLICT, "publicId 已存在", 409)
        return public_id

    while True:
        public_id = generate_public_id("U")
        exists = db.scalar(select(User.id).where(User.public_id == public_id))
        if exists is None:
            return public_id


def _unique_team_public_id(db: Session) -> str:
    while True:
        public_id = generate_public_id()
        exists = db.scalar(select(Team.id).where(Team.public_id == public_id))
        if exists is None:
            return public_id


def _mark_match_scheduled(match: Match) -> None:
    if not match.team_a_id or not match.team_b_id:
        match.status = "scheduled"


def _ensure_team_exists(db: Session, team_id: str) -> Team:
    team = db.scalar(select(Team).where(Team.id == team_id))
    if team is None:
        raise AppException(ErrorCode.NOT_FOUND, "队伍不存在", 404)
    return team


def _upsert_tournament_participant(db: Session, tournament_id: str, team_id: str) -> None:
    participant = db.scalar(
        select(TournamentParticipant).where(
            TournamentParticipant.tournament_id == tournament_id,
            TournamentParticipant.team_id == team_id,
        )
    )
    if participant is not None:
        participant.status = "confirmed"
        db.add(participant)
        return

    seed = int(
        db.scalar(
            select(func.count())
            .select_from(TournamentParticipant)
            .where(TournamentParticipant.tournament_id == tournament_id)
        )
        or 0
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
        return

    required_slots = len(match_positions(match.format))
    team_a_count = int(
        db.scalar(
            select(func.count())
            .select_from(MatchRoster)
            .where(
                MatchRoster.match_id == match.id,
                MatchRoster.team_id == match.team_a_id,
                MatchRoster.status == 0,
            )
        )
        or 0
    )
    team_b_count = int(
        db.scalar(
            select(func.count())
            .select_from(MatchRoster)
            .where(
                MatchRoster.match_id == match.id,
                MatchRoster.team_id == match.team_b_id,
                MatchRoster.status == 0,
            )
        )
        or 0
    )
    match.status = "ready" if team_a_count >= required_slots and team_b_count >= required_slots else "scheduled"


def _sync_match_teams(
    db: Session,
    *,
    tournament_id: str,
    team_a_id: str | None,
    team_b_id: str | None,
) -> tuple[str | None, str | None]:
    normalized_team_a = team_a_id.strip() if team_a_id else None
    normalized_team_b = team_b_id.strip() if team_b_id else None
    if normalized_team_a and normalized_team_b and normalized_team_a == normalized_team_b:
        raise AppException(ErrorCode.MATCH_TEAM_DUPLICATED, "A 队与 B 队不能是同一支队伍", 409)

    for team_id in (normalized_team_a, normalized_team_b):
        if not team_id:
            continue
        _ensure_team_exists(db, team_id)
        _upsert_tournament_participant(db, tournament_id, team_id)

    return normalized_team_a, normalized_team_b


def _write_audit_log(
    db: Session,
    *,
    actor_admin_id: str,
    resource_type: str,
    resource_id: str,
    action: str,
    before: dict[str, Any] | None,
    after: dict[str, Any] | None,
) -> None:
    db.add(
        AdminAuditLog(
            actor_admin_id=actor_admin_id,
            resource_type=resource_type,
            resource_id=resource_id,
            action=action,
            before_json=_json_safe(before),
            after_json=_json_safe(after),
        )
    )


def _user_list_item(user: User) -> dict[str, Any]:
    return AdminUserListItemOut(
        id=user.id,
        publicId=user.public_id,
        nickname=user.nickname,
        avatarUrl=user.avatar_url,
        status=user.status,
        deletedAt=user.deleted_at,
        createdAt=user.created_at,
        updatedAt=user.updated_at,
    ).model_dump()


def _user_detail(user: User) -> dict[str, Any]:
    return AdminUserDetailOut(
        **_user_list_item(user),
        appleSub=user.apple_sub,
    ).model_dump()


def _team_owner_nickname(db: Session, owner_id: str) -> str | None:
    owner = db.scalar(select(User).where(User.id == owner_id))
    return owner.nickname if owner else None


def _team_member_count(db: Session, team_id: str) -> int:
    return int(
        db.scalar(
            select(func.count()).select_from(TeamMember).where(
                TeamMember.team_id == team_id,
                TeamMember.status == 0,
            )
        )
        or 0
    )


def _team_list_item(db: Session, team: Team) -> dict[str, Any]:
    return AdminTeamListItemOut(
        id=team.id,
        publicId=team.public_id,
        name=team.name,
        intro=team.intro,
        avatarUrl=team.avatar_url,
        ownerId=team.owner_id,
        ownerNickname=_team_owner_nickname(db, team.owner_id),
        status=team.status,
        memberCount=_team_member_count(db, team.id),
        createdAt=team.created_at,
        updatedAt=team.updated_at,
    ).model_dump()


def _join_request_reviewed_by_nickname(db: Session, reviewed_by_user_id: str | None) -> str | None:
    if not reviewed_by_user_id:
        return None
    reviewer = db.scalar(select(User).where(User.id == reviewed_by_user_id))
    return reviewer.nickname if reviewer else None


def _join_request_out(db: Session, req: TeamJoinRequest) -> dict[str, Any]:
    team = db.scalar(select(Team).where(Team.id == req.team_id))
    applicant = db.scalar(select(User).where(User.id == req.applicant_user_id))
    return AdminJoinRequestOut(
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
        reviewedByNickname=_join_request_reviewed_by_nickname(db, req.reviewed_by_user_id),
    ).model_dump()


def _team_detail(db: Session, team: Team) -> dict[str, Any]:
    payload = team_out(db, team)
    join_requests = db.scalars(
        select(TeamJoinRequest)
        .where(TeamJoinRequest.team_id == team.id)
        .order_by(TeamJoinRequest.created_at.desc())
    ).all()
    return AdminTeamDetailOut(
        **_team_list_item(db, team),
        members=payload["members"],
        joinRequests=[_join_request_out(db, req) for req in join_requests],
    ).model_dump()


def _tournament_creator_nickname(db: Session, creator_id: str) -> str | None:
    creator = db.scalar(select(User).where(User.id == creator_id))
    return creator.nickname if creator else None


def _tournament_match_count(db: Session, tournament_id: str) -> int:
    return int(
        db.scalar(
            select(func.count()).select_from(Match).where(Match.tournament_id == tournament_id)
        )
        or 0
    )


def _tournament_participant_count(db: Session, tournament_id: str) -> int:
    return int(
        db.scalar(
            select(func.count())
            .select_from(TournamentParticipant)
            .where(TournamentParticipant.tournament_id == tournament_id)
        )
        or 0
    )


def _tournament_list_item(db: Session, tournament: Tournament) -> dict[str, Any]:
    return AdminTournamentListItemOut(
        id=tournament.id,
        name=tournament.name,
        intro=tournament.intro,
        coverUrl=tournament.cover_url,
        creatorId=tournament.creator_id,
        creatorNickname=_tournament_creator_nickname(db, tournament.creator_id),
        status=tournament.status,
        startDate=tournament.start_date,
        endDate=tournament.end_date,
        participantCount=_tournament_participant_count(db, tournament.id),
        matchCount=_tournament_match_count(db, tournament.id),
        createdAt=tournament.created_at,
        updatedAt=tournament.updated_at,
    ).model_dump()


def _team_label(db: Session, team_id: str | None) -> tuple[str | None, str | None]:
    if not team_id:
        return None, None
    team = db.scalar(select(Team).where(Team.id == team_id))
    if team is None:
        return None, None
    return team.name, team.public_id


def _tournament_participant_out(db: Session, participant: TournamentParticipant) -> dict[str, Any]:
    team = db.scalar(select(Team).where(Team.id == participant.team_id))
    return AdminTournamentParticipantOut(
        id=participant.id,
        tournamentId=participant.tournament_id,
        teamId=participant.team_id,
        status=participant.status,
        seed=participant.seed,
        teamName=team.name if team else None,
        teamPublicId=team.public_id if team else None,
    ).model_dump()


def _match_roster_out(db: Session, roster: MatchRoster) -> dict[str, Any]:
    team = db.scalar(select(Team).where(Team.id == roster.team_id))
    user = db.scalar(select(User).where(User.id == roster.user_id))
    return AdminMatchRosterOut(
        id=roster.id,
        matchId=roster.match_id,
        teamId=roster.team_id,
        userId=roster.user_id,
        position=roster.position,
        status=roster.status,
        nickname=user.nickname if user else None,
        publicId=user.public_id if user else None,
        teamName=team.name if team else None,
        teamPublicId=team.public_id if team else None,
    ).model_dump()


def _tournament_detail(db: Session, tournament: Tournament) -> dict[str, Any]:
    matches = db.scalars(
        select(Match)
        .where(Match.tournament_id == tournament.id)
        .order_by(Match.start_time.asc(), Match.created_at.asc())
    ).all()
    return AdminTournamentDetailOut(
        **_tournament_list_item(db, tournament),
        participants=[
            _tournament_participant_out(db, participant)
            for participant in db.scalars(
                select(TournamentParticipant)
                .where(TournamentParticipant.tournament_id == tournament.id)
                .order_by(TournamentParticipant.seed.asc(), TournamentParticipant.created_at.asc())
            ).all()
        ],
        matches=[_match_detail(db, match) for match in matches],
    ).model_dump()


def _match_detail(db: Session, match: Match) -> dict[str, Any]:
    payload = match_out(db, match)
    payload.pop("rosters", None)
    tournament = db.scalar(select(Tournament).where(Tournament.id == match.tournament_id))
    team_a_name, team_a_public_id = _team_label(db, match.team_a_id)
    team_b_name, team_b_public_id = _team_label(db, match.team_b_id)
    return AdminMatchOut(
        **payload,
        tournamentName=tournament.name if tournament else None,
        teamAName=team_a_name,
        teamAPublicId=team_a_public_id,
        teamBName=team_b_name,
        teamBPublicId=team_b_public_id,
        rosters=[
            _match_roster_out(db, roster)
            for roster in db.scalars(
                select(MatchRoster)
                .where(MatchRoster.match_id == match.id)
                .order_by(MatchRoster.team_id.asc(), MatchRoster.position.asc())
            ).all()
        ],
    ).model_dump()


@router.post("/auth/login", response_model=AdminTokenBundleOut)
def admin_login(payload: AdminLoginIn, db: Session = Depends(get_db)):
    admin = db.scalar(select(AdminUser).where(AdminUser.email == _normalize_email(payload.email)))
    if admin is None or not verify_password(payload.password, admin.password_hash):
        raise AppException(
            ErrorCode.ADMIN_EMAIL_PASSWORD_INVALID,
            "后台邮箱或密码错误。",
            401,
        )

    ensure_active_admin(admin)
    admin.last_login_at = _now()
    db.add(admin)
    db.commit()
    return _issue_admin_tokens(db, admin)


@router.post("/auth/refresh", response_model=AdminTokenBundleOut)
def admin_refresh(payload: AdminRefreshTokenIn, db: Session = Depends(get_db)):
    token_payload, saved = _decode_admin_refresh_token(payload.refreshToken, db)
    admin_id = token_payload.get("sub")
    if not admin_id:
        raise AppException(ErrorCode.ADMIN_UNAUTHORIZED, "后台 refresh token 缺少 sub", 401)

    admin = db.scalar(select(AdminUser).where(AdminUser.id == admin_id))
    if admin is None:
        raise AppException(ErrorCode.ADMIN_UNAUTHORIZED, "后台管理员不存在", 401)
    ensure_active_admin(admin)

    return _issue_admin_tokens(db, admin)


@router.post("/auth/logout", response_model=AdminLogoutOut)
def admin_logout(payload: AdminRefreshTokenIn, db: Session = Depends(get_db)):
    _, saved = _decode_admin_refresh_token(payload.refreshToken, db)
    saved.revoked_at = saved.revoked_at or _now()
    db.add(saved)
    db.commit()
    return {"ok": True}


@router.get("/auth/me", response_model=AdminOut)
def admin_me(current_admin: AdminUser = Depends(get_current_admin_user)):
    return _admin_out(current_admin)


@router.get("/overview", response_model=AdminOverviewOut)
def admin_overview(_: AdminUser = Depends(get_current_admin_user), db: Session = Depends(get_db)):
    users_total = int(db.scalar(select(func.count()).select_from(User)) or 0)
    users_normal = int(
        db.scalar(select(func.count()).select_from(User).where(User.status == UserStatus.NORMAL)) or 0
    )
    users_deleted = int(
        db.scalar(select(func.count()).select_from(User).where(User.status == UserStatus.DELETED)) or 0
    )
    users_banned = int(
        db.scalar(select(func.count()).select_from(User).where(User.status == UserStatus.BANNED)) or 0
    )

    teams_total = int(db.scalar(select(func.count()).select_from(Team)) or 0)
    teams_active = int(db.scalar(select(func.count()).select_from(Team).where(Team.status == 0)) or 0)

    tournaments_total = int(db.scalar(select(func.count()).select_from(Tournament)) or 0)
    tournaments_open = int(
        db.scalar(
            select(func.count()).select_from(Tournament).where(
                Tournament.status == TournamentStatus.OPEN
            )
        )
        or 0
    )
    tournaments_ongoing = int(
        db.scalar(
            select(func.count()).select_from(Tournament).where(
                Tournament.status == TournamentStatus.ONGOING
            )
        )
        or 0
    )
    tournaments_ended = int(
        db.scalar(
            select(func.count()).select_from(Tournament).where(
                Tournament.status == TournamentStatus.ENDED
            )
        )
        or 0
    )

    latest_activity_candidates = [
        db.scalar(select(func.max(User.updated_at))),
        db.scalar(select(func.max(Team.updated_at))),
        db.scalar(select(func.max(Tournament.updated_at))),
        db.scalar(select(func.max(Match.updated_at))),
    ]
    latest_activity = max(
        (item for item in latest_activity_candidates if item is not None),
        default=None,
    )

    return {
        "users": {
            "total": users_total,
            "normal": users_normal,
            "deleted": users_deleted,
            "banned": users_banned,
        },
        "teams": {
            "total": teams_total,
            "active": teams_active,
            "inactive": max(teams_total - teams_active, 0),
        },
        "tournaments": {
            "total": tournaments_total,
            "open": tournaments_open,
            "ongoing": tournaments_ongoing,
            "ended": tournaments_ended,
        },
        "latestActivityAt": latest_activity,
    }


@router.get("/users", response_model=AdminUserListOut)
def admin_list_users(
    q: str = Query(default="", max_length=50),
    status: int | None = Query(default=None),
    cursor: str | None = None,
    limit: int = Query(default=20, ge=1, le=100),
    _: AdminUser = Depends(get_current_admin_user),
    db: Session = Depends(get_db),
):
    start = int(cursor or "0")
    query = select(User)
    keyword = q.strip()
    if keyword:
        query = query.where(
            or_(
                User.public_id.ilike(f"%{keyword}%"),
                User.nickname.ilike(f"%{keyword}%"),
            )
        )
    if status is not None:
        query = query.where(User.status == status)

    rows = db.scalars(
        query.order_by(User.updated_at.desc(), User.created_at.desc()).offset(start).limit(limit + 1)
    ).all()
    next_cursor = str(start + limit) if len(rows) > limit else None
    rows = rows[:limit]

    return {"items": [_user_list_item(row) for row in rows], "nextCursor": next_cursor}


@router.get("/users/{user_id}", response_model=AdminUserDetailOut)
def admin_get_user(
    user_id: str,
    _: AdminUser = Depends(get_current_admin_user),
    db: Session = Depends(get_db),
):
    user = db.scalar(select(User).where(User.id == user_id))
    if user is None:
        raise AppException(ErrorCode.NOT_FOUND, "用户不存在", 404)
    return _user_detail(user)


@router.post("/users", response_model=AdminUserDetailOut)
def admin_create_user(
    payload: AdminUserCreateIn,
    current_admin: AdminUser = Depends(get_current_admin_user),
    db: Session = Depends(get_db),
):
    user = User(
        public_id=_unique_user_public_id(db, payload.public_id),
        nickname=payload.nickname.strip(),
        avatar_url=payload.avatar_url,
        status=payload.status,
        apple_sub=None,
        deleted_at=None,
    )
    db.add(user)
    db.flush()

    after = _user_detail(user)
    _write_audit_log(
        db,
        actor_admin_id=current_admin.id,
        resource_type="user",
        resource_id=user.id,
        action="create",
        before=None,
        after=after,
    )
    db.commit()
    db.refresh(user)
    return _user_detail(user)


@router.patch("/users/{user_id}", response_model=AdminUserDetailOut)
def admin_update_user(
    user_id: str,
    payload: AdminUserUpdateIn,
    current_admin: AdminUser = Depends(get_current_admin_user),
    db: Session = Depends(get_db),
):
    user = db.scalar(select(User).where(User.id == user_id))
    if user is None:
        raise AppException(ErrorCode.NOT_FOUND, "用户不存在", 404)

    before = _user_detail(user)
    user.nickname = payload.nickname.strip()
    user.avatar_url = payload.avatar_url
    user.status = payload.status
    db.add(user)
    db.flush()

    after = _user_detail(user)
    _write_audit_log(
        db,
        actor_admin_id=current_admin.id,
        resource_type="user",
        resource_id=user.id,
        action="update",
        before=before,
        after=after,
    )
    db.commit()
    db.refresh(user)
    return _user_detail(user)


@router.delete("/users/{user_id}", response_model=AdminMutationOut)
def admin_delete_user(
    user_id: str,
    current_admin: AdminUser = Depends(get_current_admin_user),
    db: Session = Depends(get_db),
):
    user = db.scalar(select(User).where(User.id == user_id))
    if user is None:
        raise AppException(ErrorCode.NOT_FOUND, "用户不存在", 404)

    before = _user_detail(user)
    deleted_at = _now()
    user.status = UserStatus.DELETED
    user.deleted_at = deleted_at
    user.apple_sub = None
    db.add(user)

    identities = db.scalars(select(UserAuthIdentity).where(UserAuthIdentity.user_id == user.id)).all()
    for identity in identities:
        db.delete(identity)

    tokens = db.scalars(select(RefreshToken).where(RefreshToken.user_id == user.id)).all()
    for token in tokens:
        token.revoked_at = token.revoked_at or deleted_at
        db.add(token)

    after = _user_detail(user)
    _write_audit_log(
        db,
        actor_admin_id=current_admin.id,
        resource_type="user",
        resource_id=user.id,
        action="delete",
        before=before,
        after=after,
    )
    db.commit()
    return {"ok": True, "resourceId": user.id}


@router.get("/teams", response_model=AdminTeamListOut)
def admin_list_teams(
    q: str = Query(default="", max_length=50),
    status: int | None = Query(default=None),
    cursor: str | None = None,
    limit: int = Query(default=20, ge=1, le=100),
    _: AdminUser = Depends(get_current_admin_user),
    db: Session = Depends(get_db),
):
    start = int(cursor or "0")
    query = select(Team)
    keyword = q.strip()
    if keyword:
        query = query.where(
            or_(Team.public_id.ilike(f"%{keyword}%"), Team.name.ilike(f"%{keyword}%"))
        )
    if status is not None:
        query = query.where(Team.status == status)

    rows = db.scalars(
        query.order_by(Team.updated_at.desc(), Team.created_at.desc()).offset(start).limit(limit + 1)
    ).all()
    next_cursor = str(start + limit) if len(rows) > limit else None
    rows = rows[:limit]

    return {"items": [_team_list_item(db, row) for row in rows], "nextCursor": next_cursor}


@router.get("/teams/{team_id}", response_model=AdminTeamDetailOut)
def admin_get_team(
    team_id: str,
    _: AdminUser = Depends(get_current_admin_user),
    db: Session = Depends(get_db),
):
    team = db.scalar(select(Team).where(Team.id == team_id))
    if team is None:
        raise AppException(ErrorCode.NOT_FOUND, "队伍不存在", 404)
    return _team_detail(db, team)


@router.get("/team-join-requests", response_model=AdminTeamJoinRequestListOut)
def admin_list_team_join_requests(
    team_id: str | None = Query(default=None),
    applicant_user_id: str | None = Query(default=None),
    status: str | None = Query(default=None, pattern="^(pending|approved|rejected)$"),
    q: str = Query(default="", max_length=50),
    cursor: str | None = None,
    limit: int = Query(default=20, ge=1, le=100),
    _: AdminUser = Depends(get_current_admin_user),
    db: Session = Depends(get_db),
):
    start = int(cursor or "0")
    query = select(TeamJoinRequest).join(Team, Team.id == TeamJoinRequest.team_id).join(
        User, User.id == TeamJoinRequest.applicant_user_id
    )

    if team_id:
        query = query.where(TeamJoinRequest.team_id == team_id)
    if applicant_user_id:
        query = query.where(TeamJoinRequest.applicant_user_id == applicant_user_id)
    if status:
        query = query.where(TeamJoinRequest.status == status)

    keyword = q.strip()
    if keyword:
        query = query.where(
            or_(
                Team.name.ilike(f"%{keyword}%"),
                Team.public_id.ilike(f"%{keyword}%"),
                User.nickname.ilike(f"%{keyword}%"),
                User.public_id.ilike(f"%{keyword}%"),
            )
        )

    rows = db.scalars(
        query.order_by(TeamJoinRequest.created_at.desc()).offset(start).limit(limit + 1)
    ).all()
    next_cursor = str(start + limit) if len(rows) > limit else None
    rows = rows[:limit]

    return {"items": [_join_request_out(db, row) for row in rows], "nextCursor": next_cursor}


@router.post("/team-join-requests/{request_id}:approve", response_model=AdminJoinRequestOut)
def admin_approve_team_join_request(
    request_id: str,
    current_admin: AdminUser = Depends(get_current_admin_user),
    db: Session = Depends(get_db),
):
    req = db.scalar(select(TeamJoinRequest).where(TeamJoinRequest.id == request_id))
    if req is None:
        raise AppException(ErrorCode.NOT_FOUND, "申请不存在", 404)
    if req.status != TeamJoinRequestStatus.PENDING:
        raise AppException(ErrorCode.CONFLICT, "申请已处理", 409)

    team = _ensure_team_exists(db, req.team_id)
    applicant = _ensure_active_business_user(db, req.applicant_user_id)
    before = _join_request_out(db, req)

    member = db.scalar(
        select(TeamMember).where(TeamMember.team_id == team.id, TeamMember.user_id == applicant.id)
    )
    if member is None:
        db.add(
            TeamMember(
                team_id=team.id,
                user_id=applicant.id,
                role=int(TeamRole.OWNER if team.owner_id == applicant.id else TeamRole.MEMBER),
                status=0,
            )
        )
    elif member.status != 0:
        member.status = 0
        member.role = int(TeamRole.OWNER if team.owner_id == applicant.id else TeamRole.MEMBER)
        member.join_time = _now()
        db.add(member)

    req.status = TeamJoinRequestStatus.APPROVED
    req.reviewed_at = _now()
    req.reviewed_by_user_id = None
    db.add(
        Message(
            recipient_user_id=applicant.id,
            kind="statusChange",
            title="入队申请已通过",
            subtitle="你提交的申请已被管理员通过",
            payload={"teamId": req.team_id, "joinRequestId": req.id, "status": "approved"},
        )
    )
    db.add(req)
    db.flush()

    after = _join_request_out(db, req)
    _write_audit_log(
        db,
        actor_admin_id=current_admin.id,
        resource_type="team_join_request",
        resource_id=req.id,
        action="approve",
        before=before,
        after=after,
    )
    db.commit()
    db.refresh(req)
    return _join_request_out(db, req)


@router.post("/team-join-requests/{request_id}:reject", response_model=AdminJoinRequestOut)
def admin_reject_team_join_request(
    request_id: str,
    current_admin: AdminUser = Depends(get_current_admin_user),
    db: Session = Depends(get_db),
):
    req = db.scalar(select(TeamJoinRequest).where(TeamJoinRequest.id == request_id))
    if req is None:
        raise AppException(ErrorCode.NOT_FOUND, "申请不存在", 404)
    if req.status != TeamJoinRequestStatus.PENDING:
        raise AppException(ErrorCode.CONFLICT, "申请已处理", 409)

    before = _join_request_out(db, req)
    applicant = _ensure_active_business_user(db, req.applicant_user_id)

    req.status = TeamJoinRequestStatus.REJECTED
    req.reviewed_at = _now()
    req.reviewed_by_user_id = None
    db.add(
        Message(
            recipient_user_id=applicant.id,
            kind="statusChange",
            title="入队申请已拒绝",
            subtitle="你提交的申请未通过审核",
            payload={"teamId": req.team_id, "joinRequestId": req.id, "status": "rejected"},
        )
    )
    db.add(req)
    db.flush()

    after = _join_request_out(db, req)
    _write_audit_log(
        db,
        actor_admin_id=current_admin.id,
        resource_type="team_join_request",
        resource_id=req.id,
        action="reject",
        before=before,
        after=after,
    )
    db.commit()
    db.refresh(req)
    return _join_request_out(db, req)


@router.post("/teams/{team_id}/members", response_model=AdminTeamDetailOut)
def admin_add_team_member(
    team_id: str,
    payload: AdminTeamMemberAddIn,
    current_admin: AdminUser = Depends(get_current_admin_user),
    db: Session = Depends(get_db),
):
    team = _ensure_team_exists(db, team_id)
    user = _ensure_active_business_user(db, payload.user_id)
    before = _team_detail(db, team)

    member = db.scalar(
        select(TeamMember).where(TeamMember.team_id == team.id, TeamMember.user_id == user.id)
    )
    role = int(TeamRole.OWNER if team.owner_id == user.id else TeamRole.MEMBER)
    if member is None:
        member = TeamMember(team_id=team.id, user_id=user.id, role=role, status=0)
        db.add(member)
    elif member.status == 0:
        raise AppException(ErrorCode.CONFLICT, "成员已存在", 409)
    else:
        member.status = 0
        member.role = role
        member.join_time = _now()
        db.add(member)

    db.flush()
    after = _team_detail(db, team)
    _write_audit_log(
        db,
        actor_admin_id=current_admin.id,
        resource_type="team_member",
        resource_id=member.id,
        action="add",
        before=before,
        after=after,
    )
    db.commit()
    db.refresh(team)
    return _team_detail(db, team)


@router.post("/teams/{team_id}/members/{member_id}:set-admin", response_model=AdminTeamDetailOut)
def admin_set_team_member_admin(
    team_id: str,
    member_id: str,
    payload: AdminTeamMemberSetAdminIn,
    current_admin: AdminUser = Depends(get_current_admin_user),
    db: Session = Depends(get_db),
):
    team = _ensure_team_exists(db, team_id)
    member = db.scalar(
        select(TeamMember).where(TeamMember.id == member_id, TeamMember.team_id == team_id)
    )
    if member is None or member.status != 0:
        raise AppException(ErrorCode.NOT_FOUND, "成员不存在", 404)
    if member.role == TeamRole.OWNER:
        raise AppException(ErrorCode.TEAM_OWNER_IMMUTABLE, "队长不能调整管理员状态", 409)

    before = _team_detail(db, team)
    member.role = int(TeamRole.ADMIN if payload.is_admin else TeamRole.MEMBER)
    db.add(member)
    db.flush()

    after = _team_detail(db, team)
    _write_audit_log(
        db,
        actor_admin_id=current_admin.id,
        resource_type="team_member",
        resource_id=member.id,
        action="set_admin",
        before=before,
        after=after,
    )
    db.commit()
    db.refresh(team)
    return _team_detail(db, team)


@router.post("/teams/{team_id}:transfer-owner", response_model=AdminTeamDetailOut)
def admin_transfer_team_owner(
    team_id: str,
    payload: AdminTransferOwnerIn,
    current_admin: AdminUser = Depends(get_current_admin_user),
    db: Session = Depends(get_db),
):
    team = _ensure_team_exists(db, team_id)
    target = db.scalar(
        select(TeamMember).where(TeamMember.id == payload.member_id, TeamMember.team_id == team_id)
    )
    if target is None or target.status != 0:
        raise AppException(ErrorCode.NOT_FOUND, "目标成员不存在", 404)

    current_owner = db.scalar(
        select(TeamMember).where(TeamMember.team_id == team_id, TeamMember.user_id == team.owner_id)
    )
    if current_owner is None or current_owner.status != 0:
        raise AppException(ErrorCode.NOT_FOUND, "当前队长成员关系缺失", 404)
    if target.role == TeamRole.OWNER:
        raise AppException(ErrorCode.CONFLICT, "目标成员已经是队长", 409)

    before = _team_detail(db, team)
    current_owner.role = int(TeamRole.ADMIN)
    target.role = int(TeamRole.OWNER)
    team.owner_id = target.user_id
    db.add(current_owner)
    db.add(target)
    db.add(team)
    db.flush()

    after = _team_detail(db, team)
    _write_audit_log(
        db,
        actor_admin_id=current_admin.id,
        resource_type="team",
        resource_id=team.id,
        action="transfer_owner",
        before=before,
        after=after,
    )
    db.commit()
    db.refresh(team)
    return _team_detail(db, team)


@router.delete("/teams/{team_id}/members/{member_id}", response_model=AdminTeamDetailOut)
def admin_remove_team_member(
    team_id: str,
    member_id: str,
    current_admin: AdminUser = Depends(get_current_admin_user),
    db: Session = Depends(get_db),
):
    team = _ensure_team_exists(db, team_id)
    member = db.scalar(
        select(TeamMember).where(TeamMember.id == member_id, TeamMember.team_id == team_id)
    )
    if member is None or member.status != 0:
        raise AppException(ErrorCode.NOT_FOUND, "成员不存在", 404)
    if member.role == TeamRole.OWNER:
        raise AppException(ErrorCode.TEAM_OWNER_IMMUTABLE, "队长不可被移除", 409)

    before = _team_detail(db, team)
    member.status = 2
    db.add(member)
    db.flush()

    after = _team_detail(db, team)
    _write_audit_log(
        db,
        actor_admin_id=current_admin.id,
        resource_type="team_member",
        resource_id=member.id,
        action="remove",
        before=before,
        after=after,
    )
    db.commit()
    db.refresh(team)
    return _team_detail(db, team)


@router.post("/teams", response_model=AdminTeamDetailOut)
def admin_create_team(
    payload: AdminTeamCreateIn,
    current_admin: AdminUser = Depends(get_current_admin_user),
    db: Session = Depends(get_db),
):
    owner = _ensure_active_business_user(db, payload.owner_id)
    team = Team(
        public_id=_unique_team_public_id(db),
        name=payload.name.strip(),
        intro=payload.intro,
        avatar_url=payload.avatar_url,
        owner_id=owner.id,
        status=payload.status,
    )
    db.add(team)
    db.flush()
    db.add(
        TeamMember(
            team_id=team.id,
            user_id=owner.id,
            role=2,
            status=0,
        )
    )
    db.flush()

    after = _team_detail(db, team)
    _write_audit_log(
        db,
        actor_admin_id=current_admin.id,
        resource_type="team",
        resource_id=team.id,
        action="create",
        before=None,
        after=after,
    )
    db.commit()
    db.refresh(team)
    return _team_detail(db, team)


@router.patch("/teams/{team_id}", response_model=AdminTeamDetailOut)
def admin_update_team(
    team_id: str,
    payload: AdminTeamUpdateIn,
    current_admin: AdminUser = Depends(get_current_admin_user),
    db: Session = Depends(get_db),
):
    team = db.scalar(select(Team).where(Team.id == team_id))
    if team is None:
        raise AppException(ErrorCode.NOT_FOUND, "队伍不存在", 404)

    before = _team_detail(db, team)
    team.name = payload.name.strip()
    team.intro = payload.intro
    team.avatar_url = payload.avatar_url
    team.status = payload.status
    db.add(team)
    db.flush()

    after = _team_detail(db, team)
    _write_audit_log(
        db,
        actor_admin_id=current_admin.id,
        resource_type="team",
        resource_id=team.id,
        action="update",
        before=before,
        after=after,
    )
    db.commit()
    db.refresh(team)
    return _team_detail(db, team)


@router.delete("/teams/{team_id}", response_model=AdminMutationOut)
def admin_delete_team(
    team_id: str,
    current_admin: AdminUser = Depends(get_current_admin_user),
    db: Session = Depends(get_db),
):
    team = db.scalar(select(Team).where(Team.id == team_id))
    if team is None:
        raise AppException(ErrorCode.NOT_FOUND, "队伍不存在", 404)

    before = _team_detail(db, team)
    related_matches = db.scalars(
        select(Match).where(
            or_(
                Match.team_a_id == team.id,
                Match.team_b_id == team.id,
                Match.winner_team_id == team.id,
            )
        )
    ).all()
    for match in related_matches:
        if match.team_a_id == team.id:
            match.team_a_id = None
        if match.team_b_id == team.id:
            match.team_b_id = None
        if match.winner_team_id == team.id:
            match.winner_team_id = None
        _mark_match_scheduled(match)
        db.add(match)

    db.delete(team)
    db.flush()
    _write_audit_log(
        db,
        actor_admin_id=current_admin.id,
        resource_type="team",
        resource_id=team.id,
        action="delete",
        before=before,
        after=None,
    )
    db.commit()
    return {"ok": True, "resourceId": team.id}


@router.get("/tournaments", response_model=AdminTournamentListOut)
def admin_list_tournaments(
    q: str = Query(default="", max_length=50),
    status: int | None = Query(default=None),
    cursor: str | None = None,
    limit: int = Query(default=20, ge=1, le=100),
    _: AdminUser = Depends(get_current_admin_user),
    db: Session = Depends(get_db),
):
    start = int(cursor or "0")
    query = select(Tournament)
    keyword = q.strip()
    if keyword:
        query = query.where(Tournament.name.ilike(f"%{keyword}%"))
    if status is not None:
        query = query.where(Tournament.status == status)

    rows = db.scalars(
        query.order_by(Tournament.updated_at.desc(), Tournament.created_at.desc())
        .offset(start)
        .limit(limit + 1)
    ).all()
    next_cursor = str(start + limit) if len(rows) > limit else None
    rows = rows[:limit]

    return {"items": [_tournament_list_item(db, row) for row in rows], "nextCursor": next_cursor}


@router.get("/tournaments/{tournament_id}", response_model=AdminTournamentDetailOut)
def admin_get_tournament(
    tournament_id: str,
    _: AdminUser = Depends(get_current_admin_user),
    db: Session = Depends(get_db),
):
    tournament = db.scalar(select(Tournament).where(Tournament.id == tournament_id))
    if tournament is None:
        raise AppException(ErrorCode.NOT_FOUND, "赛事不存在", 404)
    return _tournament_detail(db, tournament)


@router.get("/tournaments/{tournament_id}/participants", response_model=AdminTournamentParticipantListOut)
def admin_list_tournament_participants(
    tournament_id: str,
    cursor: str | None = None,
    limit: int = Query(default=50, ge=1, le=200),
    _: AdminUser = Depends(get_current_admin_user),
    db: Session = Depends(get_db),
):
    tournament = db.scalar(select(Tournament).where(Tournament.id == tournament_id))
    if tournament is None:
        raise AppException(ErrorCode.NOT_FOUND, "赛事不存在", 404)

    start = int(cursor or "0")
    rows = db.scalars(
        select(TournamentParticipant)
        .where(TournamentParticipant.tournament_id == tournament_id)
        .order_by(TournamentParticipant.seed.asc(), TournamentParticipant.created_at.asc())
        .offset(start)
        .limit(limit + 1)
    ).all()
    next_cursor = str(start + limit) if len(rows) > limit else None
    rows = rows[:limit]
    return {
        "items": [_tournament_participant_out(db, row) for row in rows],
        "nextCursor": next_cursor,
    }


@router.post("/tournaments/{tournament_id}/participants", response_model=AdminTournamentDetailOut)
def admin_add_tournament_participant(
    tournament_id: str,
    payload: AdminTournamentParticipantCreateIn,
    current_admin: AdminUser = Depends(get_current_admin_user),
    db: Session = Depends(get_db),
):
    tournament = db.scalar(select(Tournament).where(Tournament.id == tournament_id))
    if tournament is None:
        raise AppException(ErrorCode.NOT_FOUND, "赛事不存在", 404)
    _ensure_team_exists(db, payload.team_id)

    before = _tournament_detail(db, tournament)
    _upsert_tournament_participant(db, tournament_id, payload.team_id)
    db.flush()
    participant = db.scalar(
        select(TournamentParticipant).where(
            TournamentParticipant.tournament_id == tournament_id,
            TournamentParticipant.team_id == payload.team_id,
        )
    )
    if participant is None:
        raise AppException(ErrorCode.CONFLICT, "参赛关系创建失败", 409)

    participant.status = TournamentParticipantStatus.CONFIRMED
    db.add(participant)
    db.flush()

    after = _tournament_detail(db, tournament)
    _write_audit_log(
        db,
        actor_admin_id=current_admin.id,
        resource_type="tournament_participant",
        resource_id=participant.id,
        action="add",
        before=before,
        after=after,
    )
    db.commit()
    db.refresh(tournament)
    return _tournament_detail(db, tournament)


@router.delete(
    "/tournaments/{tournament_id}/participants/{participant_id}",
    response_model=AdminTournamentDetailOut,
)
def admin_remove_tournament_participant(
    tournament_id: str,
    participant_id: str,
    current_admin: AdminUser = Depends(get_current_admin_user),
    db: Session = Depends(get_db),
):
    tournament = db.scalar(select(Tournament).where(Tournament.id == tournament_id))
    if tournament is None:
        raise AppException(ErrorCode.NOT_FOUND, "赛事不存在", 404)

    participant = db.scalar(
        select(TournamentParticipant).where(
            TournamentParticipant.id == participant_id,
            TournamentParticipant.tournament_id == tournament_id,
        )
    )
    if participant is None:
        raise AppException(ErrorCode.NOT_FOUND, "参赛队伍不存在", 404)

    before = _tournament_detail(db, tournament)
    affected_matches = db.scalars(
        select(Match).where(
            Match.tournament_id == tournament_id,
            or_(
                Match.team_a_id == participant.team_id,
                Match.team_b_id == participant.team_id,
                Match.winner_team_id == participant.team_id,
            ),
        )
    ).all()
    for match in affected_matches:
        if match.team_a_id == participant.team_id:
            match.team_a_id = None
        if match.team_b_id == participant.team_id:
            match.team_b_id = None
        if match.winner_team_id == participant.team_id:
            match.winner_team_id = None
            match.team_a_score = None
            match.team_b_score = None
            match.result_recorded_at = None
            match.result_note = None
            match.best_debater_position = None

        rosters = db.scalars(
            select(MatchRoster).where(
                MatchRoster.match_id == match.id,
                MatchRoster.team_id == participant.team_id,
            )
        ).all()
        for roster in rosters:
            db.delete(roster)

        _refresh_match_ready_status(db, match)
        db.add(match)

    db.delete(participant)
    db.flush()

    after = _tournament_detail(db, tournament)
    _write_audit_log(
        db,
        actor_admin_id=current_admin.id,
        resource_type="tournament_participant",
        resource_id=participant_id,
        action="remove",
        before=before,
        after=after,
    )
    db.commit()
    db.refresh(tournament)
    return _tournament_detail(db, tournament)


@router.post("/tournaments", response_model=AdminTournamentDetailOut)
def admin_create_tournament(
    payload: AdminTournamentCreateIn,
    current_admin: AdminUser = Depends(get_current_admin_user),
    db: Session = Depends(get_db),
):
    creator = _ensure_active_business_user(db, payload.creator_id)
    tournament = Tournament(
        name=payload.name.strip(),
        intro=payload.intro,
        cover_url=payload.cover_url,
        creator_id=creator.id,
        status=payload.status,
        start_date=payload.start_date,
        end_date=payload.end_date,
    )
    db.add(tournament)
    db.flush()

    after = _tournament_detail(db, tournament)
    _write_audit_log(
        db,
        actor_admin_id=current_admin.id,
        resource_type="tournament",
        resource_id=tournament.id,
        action="create",
        before=None,
        after=after,
    )
    db.commit()
    db.refresh(tournament)
    return _tournament_detail(db, tournament)


@router.patch("/tournaments/{tournament_id}", response_model=AdminTournamentDetailOut)
def admin_update_tournament(
    tournament_id: str,
    payload: AdminTournamentUpdateIn,
    current_admin: AdminUser = Depends(get_current_admin_user),
    db: Session = Depends(get_db),
):
    tournament = db.scalar(select(Tournament).where(Tournament.id == tournament_id))
    if tournament is None:
        raise AppException(ErrorCode.NOT_FOUND, "赛事不存在", 404)

    before = _tournament_detail(db, tournament)
    tournament.name = payload.name.strip()
    tournament.intro = payload.intro
    tournament.cover_url = payload.cover_url
    tournament.status = payload.status
    tournament.start_date = payload.start_date
    tournament.end_date = payload.end_date
    db.add(tournament)
    db.flush()

    after = _tournament_detail(db, tournament)
    _write_audit_log(
        db,
        actor_admin_id=current_admin.id,
        resource_type="tournament",
        resource_id=tournament.id,
        action="update",
        before=before,
        after=after,
    )
    db.commit()
    db.refresh(tournament)
    return _tournament_detail(db, tournament)


@router.delete("/tournaments/{tournament_id}", response_model=AdminMutationOut)
def admin_delete_tournament(
    tournament_id: str,
    current_admin: AdminUser = Depends(get_current_admin_user),
    db: Session = Depends(get_db),
):
    tournament = db.scalar(select(Tournament).where(Tournament.id == tournament_id))
    if tournament is None:
        raise AppException(ErrorCode.NOT_FOUND, "赛事不存在", 404)

    before = _tournament_detail(db, tournament)
    matches = db.scalars(select(Match).where(Match.tournament_id == tournament.id)).all()
    match_ids = [match.id for match in matches]
    if match_ids:
        messages = db.scalars(select(Message).where(Message.related_match_id.in_(match_ids))).all()
        for message in messages:
            db.delete(message)

    db.delete(tournament)
    db.flush()
    _write_audit_log(
        db,
        actor_admin_id=current_admin.id,
        resource_type="tournament",
        resource_id=tournament.id,
        action="delete",
        before=before,
        after=None,
    )
    db.commit()
    return {"ok": True, "resourceId": tournament.id}


@router.get("/matches", response_model=AdminMatchListOut)
@router.get("/tournaments/{tournament_id}/matches", response_model=AdminMatchListOut)
def admin_list_matches(
    tournament_id: str | None = None,
    q: str = Query(default="", max_length=50),
    status: str | None = Query(default=None, pattern="^(scheduled|ready|ongoing|finished)$"),
    team_id: str | None = Query(default=None),
    cursor: str | None = None,
    limit: int = Query(default=50, ge=1, le=200),
    _: AdminUser = Depends(get_current_admin_user),
    db: Session = Depends(get_db),
):
    start = int(cursor or "0")
    query = select(Match)
    if tournament_id:
        tournament = db.scalar(select(Tournament).where(Tournament.id == tournament_id))
        if tournament is None:
            raise AppException(ErrorCode.NOT_FOUND, "赛事不存在", 404)
        query = query.where(Match.tournament_id == tournament_id)
    if status:
        query = query.where(Match.status == status)
    if team_id:
        query = query.where(or_(Match.team_a_id == team_id, Match.team_b_id == team_id))

    keyword = q.strip()
    if keyword:
        query = query.where(
            or_(
                Match.name.ilike(f"%{keyword}%"),
                Match.topic.ilike(f"%{keyword}%"),
                Match.location.ilike(f"%{keyword}%"),
                Match.opponent_team_name.ilike(f"%{keyword}%"),
            )
        )

    rows = db.scalars(
        query.order_by(Match.start_time.asc(), Match.created_at.asc()).offset(start).limit(limit + 1)
    ).all()
    next_cursor = str(start + limit) if len(rows) > limit else None
    rows = rows[:limit]
    return {"items": [_match_detail(db, row) for row in rows], "nextCursor": next_cursor}


@router.get("/matches/{match_id}", response_model=AdminMatchOut)
def admin_get_match(
    match_id: str,
    _: AdminUser = Depends(get_current_admin_user),
    db: Session = Depends(get_db),
):
    match = db.scalar(select(Match).where(Match.id == match_id))
    if match is None:
        raise AppException(ErrorCode.NOT_FOUND, "场次不存在", 404)
    return _match_detail(db, match)


@router.post("/tournaments/{tournament_id}/matches", response_model=AdminMatchOut)
def admin_create_match(
    tournament_id: str,
    payload: AdminMatchCreateIn,
    current_admin: AdminUser = Depends(get_current_admin_user),
    db: Session = Depends(get_db),
):
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
    match.team_a_id, match.team_b_id = _sync_match_teams(
        db,
        tournament_id=tournament_id,
        team_a_id=payload.team_a_id,
        team_b_id=payload.team_b_id,
    )
    db.add(match)
    db.flush()
    _refresh_match_ready_status(db, match)

    after = _match_detail(db, match)
    _write_audit_log(
        db,
        actor_admin_id=current_admin.id,
        resource_type="match",
        resource_id=match.id,
        action="create",
        before=None,
        after=after,
    )
    db.commit()
    db.refresh(match)
    return _match_detail(db, match)


@router.patch("/matches/{match_id}", response_model=AdminMatchOut)
def admin_update_match(
    match_id: str,
    payload: AdminMatchUpdateIn,
    current_admin: AdminUser = Depends(get_current_admin_user),
    db: Session = Depends(get_db),
):
    match = db.scalar(select(Match).where(Match.id == match_id))
    if match is None:
        raise AppException(ErrorCode.NOT_FOUND, "场次不存在", 404)

    before = _match_detail(db, match)
    match.name = payload.name.strip()
    match.topic = payload.topic
    match.start_time = payload.start_time
    match.end_time = payload.end_time
    match.location = payload.location
    match.format = payload.format
    match.opponent_team_name = payload.opponent_team_name
    match.team_a_id, match.team_b_id = _sync_match_teams(
        db,
        tournament_id=match.tournament_id,
        team_a_id=payload.team_a_id,
        team_b_id=payload.team_b_id,
    )
    if match.winner_team_id and match.winner_team_id not in {match.team_a_id, match.team_b_id}:
        match.winner_team_id = None
        match.team_a_score = None
        match.team_b_score = None
        match.result_recorded_at = None
        match.result_note = None
        match.best_debater_position = None
    _refresh_match_ready_status(db, match)
    db.add(match)
    db.flush()

    after = _match_detail(db, match)
    _write_audit_log(
        db,
        actor_admin_id=current_admin.id,
        resource_type="match",
        resource_id=match.id,
        action="update",
        before=before,
        after=after,
    )
    db.commit()
    db.refresh(match)
    return _match_detail(db, match)


@router.put("/matches/{match_id}/rosters/{team_id}", response_model=AdminMatchOut)
def admin_update_match_roster(
    match_id: str,
    team_id: str,
    payload: AdminMatchRosterUpdateIn,
    current_admin: AdminUser = Depends(get_current_admin_user),
    db: Session = Depends(get_db),
):
    match = db.scalar(select(Match).where(Match.id == match_id))
    if match is None:
        raise AppException(ErrorCode.NOT_FOUND, "场次不存在", 404)
    if team_id not in {match.team_a_id, match.team_b_id}:
        raise AppException(ErrorCode.NOT_FOUND, "该队伍不在本场次中", 404)

    team_members = db.scalars(
        select(TeamMember).where(TeamMember.team_id == team_id, TeamMember.status == 0)
    ).all()
    allowed_users = {member.user_id for member in team_members}
    allowed_positions = set(match_positions(match.format))

    seen_users: set[str] = set()
    seen_positions: set[str] = set()
    for assignment in payload.assignments:
        position = assignment.position.strip()
        if assignment.user_id not in allowed_users:
            raise AppException(ErrorCode.ROSTER_INVALID_MEMBER, "阵容成员必须属于该队", 409)
        if position not in allowed_positions:
            raise AppException(ErrorCode.ROSTER_INVALID_POSITION, "阵容辩位不合法", 409)
        if assignment.user_id in seen_users or position in seen_positions:
            raise AppException(ErrorCode.CONFLICT, "阵容存在重复成员或重复辩位", 409)
        seen_users.add(assignment.user_id)
        seen_positions.add(position)

    before = _match_detail(db, match)
    db.query(MatchRoster).filter(
        MatchRoster.match_id == match_id, MatchRoster.team_id == team_id
    ).delete()
    for assignment in payload.assignments:
        db.add(
            MatchRoster(
                match_id=match_id,
                team_id=team_id,
                user_id=assignment.user_id,
                position=assignment.position.strip(),
            )
        )

    db.flush()
    _refresh_match_ready_status(db, match)
    for assignment in payload.assignments:
        db.add(
            Message(
                recipient_user_id=assignment.user_id,
                kind="notification",
                title=f"你被安排参加 {match.name}",
                subtitle=f"时间：{match.start_time.isoformat()}",
                related_match_id=match.id,
                payload={"matchId": match.id, "teamId": team_id},
            )
        )

    db.add(match)
    db.flush()
    after = _match_detail(db, match)
    _write_audit_log(
        db,
        actor_admin_id=current_admin.id,
        resource_type="match_roster",
        resource_id=match.id,
        action="update",
        before=before,
        after=after,
    )
    db.commit()
    db.refresh(match)
    return _match_detail(db, match)


@router.post("/matches/{match_id}:advance-status", response_model=AdminMatchOut)
def admin_advance_match_status(
    match_id: str,
    payload: AdminMatchStatusAdvanceIn,
    current_admin: AdminUser = Depends(get_current_admin_user),
    db: Session = Depends(get_db),
):
    match = db.scalar(select(Match).where(Match.id == match_id))
    if match is None:
        raise AppException(ErrorCode.NOT_FOUND, "场次不存在", 404)

    current = match.status
    target = payload.status
    allowed = {
        MatchStatus.SCHEDULED: {MatchStatus.SCHEDULED, MatchStatus.READY, MatchStatus.ONGOING, MatchStatus.FINISHED},
        MatchStatus.READY: {MatchStatus.READY, MatchStatus.ONGOING, MatchStatus.FINISHED},
        MatchStatus.ONGOING: {MatchStatus.ONGOING, MatchStatus.FINISHED},
        MatchStatus.FINISHED: {MatchStatus.FINISHED},
    }

    if target not in allowed.get(current, set()):
        raise AppException(
            ErrorCode.MATCH_STATUS_INVALID_TRANSITION,
            f"不允许从 {current} 切换到 {target}",
            409,
        )

    before = _match_detail(db, match)
    match.status = target
    db.add(match)
    db.flush()

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

    after = _match_detail(db, match)
    _write_audit_log(
        db,
        actor_admin_id=current_admin.id,
        resource_type="match",
        resource_id=match.id,
        action="advance_status",
        before=before,
        after=after,
    )
    db.commit()
    db.refresh(match)
    return _match_detail(db, match)


@router.put("/matches/{match_id}/result", response_model=AdminMatchOut)
def admin_update_match_result(
    match_id: str,
    payload: AdminMatchResultUpdateIn,
    current_admin: AdminUser = Depends(get_current_admin_user),
    db: Session = Depends(get_db),
):
    match = db.scalar(select(Match).where(Match.id == match_id))
    if match is None:
        raise AppException(ErrorCode.NOT_FOUND, "场次不存在", 404)
    if payload.winner_team_id not in {match.team_a_id, match.team_b_id}:
        raise AppException(ErrorCode.VALIDATION_ERROR, "胜方必须是 A 队或 B 队", 400)

    before = _match_detail(db, match)
    match.winner_team_id = payload.winner_team_id
    match.team_a_score = payload.team_a_score
    match.team_b_score = payload.team_b_score
    match.result_note = payload.result_note
    match.best_debater_position = payload.best_debater_position
    match.result_recorded_at = _now()
    match.status = MatchStatus.FINISHED
    db.add(match)
    db.flush()

    after = _match_detail(db, match)
    _write_audit_log(
        db,
        actor_admin_id=current_admin.id,
        resource_type="match",
        resource_id=match.id,
        action="result",
        before=before,
        after=after,
    )
    db.commit()
    db.refresh(match)
    return _match_detail(db, match)


@router.delete("/matches/{match_id}", response_model=AdminMutationOut)
def admin_delete_match(
    match_id: str,
    current_admin: AdminUser = Depends(get_current_admin_user),
    db: Session = Depends(get_db),
):
    match = db.scalar(select(Match).where(Match.id == match_id))
    if match is None:
        raise AppException(ErrorCode.NOT_FOUND, "场次不存在", 404)

    before = _match_detail(db, match)
    messages = db.scalars(select(Message).where(Message.related_match_id == match.id)).all()
    for message in messages:
        db.delete(message)

    rosters = db.scalars(select(MatchRoster).where(MatchRoster.match_id == match.id)).all()
    for roster in rosters:
        db.delete(roster)

    db.delete(match)
    db.flush()
    _write_audit_log(
        db,
        actor_admin_id=current_admin.id,
        resource_type="match",
        resource_id=match_id,
        action="delete",
        before=before,
        after=None,
    )
    db.commit()
    return {"ok": True, "resourceId": match_id}

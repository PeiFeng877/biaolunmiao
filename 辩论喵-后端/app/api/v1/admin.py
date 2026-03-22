from __future__ import annotations

from datetime import date, datetime
from typing import Any

from fastapi import APIRouter, Depends, Query
from sqlalchemy import func, or_, select
from sqlalchemy.orm import Session

from app.api.deps import ensure_active_admin, get_current_admin_user
from app.api.v1.serializers import match_out, team_out, tournament_participants_out
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
    Message,
    RefreshToken,
    Team,
    TeamMember,
    Tournament,
    TournamentParticipant,
    User,
    UserAuthIdentity,
)
from app.models.entities import TournamentStatus, UserStatus
from app.schemas.admin import (
    AdminLoginIn,
    AdminLogoutOut,
    AdminMutationOut,
    AdminOut,
    AdminOverviewOut,
    AdminRefreshTokenIn,
    AdminTeamCreateIn,
    AdminTeamDetailOut,
    AdminTeamListItemOut,
    AdminTeamListOut,
    AdminTeamUpdateIn,
    AdminTokenBundleOut,
    AdminTournamentCreateIn,
    AdminTournamentDetailOut,
    AdminTournamentListItemOut,
    AdminTournamentListOut,
    AdminTournamentUpdateIn,
    AdminUserCreateIn,
    AdminUserDetailOut,
    AdminUserListItemOut,
    AdminUserListOut,
    AdminUserUpdateIn,
)
from app.services.common import generate_public_id

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


def _team_detail(db: Session, team: Team) -> dict[str, Any]:
    payload = team_out(db, team)
    return AdminTeamDetailOut(
        **_team_list_item(db, team),
        members=payload["members"],
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


def _tournament_detail(db: Session, tournament: Tournament) -> dict[str, Any]:
    matches = db.scalars(
        select(Match)
        .where(Match.tournament_id == tournament.id)
        .order_by(Match.start_time.asc(), Match.created_at.asc())
    ).all()
    return AdminTournamentDetailOut(
        **_tournament_list_item(db, tournament),
        participants=tournament_participants_out(db, tournament.id),
        matches=[match_out(db, match) for match in matches],
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

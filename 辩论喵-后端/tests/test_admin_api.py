# ruff: noqa: E402

import os
from datetime import datetime, timedelta
from pathlib import Path

from fastapi.testclient import TestClient
from sqlalchemy.orm import Session

TEST_DB_PATH = Path(__file__).parent / "test_admin.db"

os.environ.setdefault("DATABASE_URL", f"sqlite:///{TEST_DB_PATH}")
os.environ.setdefault("ENABLE_DEBUG_TOKEN", "true")
os.environ.setdefault("APP_ENV", "local")
os.environ.setdefault("ALLOW_INSECURE_APPLE_TOKEN_VALIDATION", "true")

from app.core.security import hash_password
from app.db.base import Base
from app.db.session import engine
from app.main import app
from app.models import AdminUser, TeamJoinRequest


def setup_function() -> None:
    engine.dispose()
    TEST_DB_PATH.unlink(missing_ok=True)
    Base.metadata.create_all(bind=engine)


def _bootstrap_admin(
    *,
    email: str = "admin@bianlunmiao.local",
    password: str = "Admin123456",
    display_name: str = "本地管理员",
) -> dict[str, str]:
    with Session(engine) as session:
        admin = AdminUser(
            email=email,
            password_hash=hash_password(password),
            display_name=display_name,
            role="super_admin",
            status=0,
        )
        session.add(admin)
        session.commit()

    return {
        "email": email,
        "password": password,
        "display_name": display_name,
    }


def _rpc(action: str, params: dict | None = None, token: str | None = None):
    headers: dict[str, str] = {}
    if token:
        headers["Authorization"] = f"Bearer {token}"
    with TestClient(app) as client:
        return client.post(
            "/api",
            json={
                "action": action,
                "params": params or {},
                "request_id": "admin-rpc-test",
            },
            headers=headers,
        )


def _login_via_rpc(email: str, password: str) -> dict:
    response = _rpc("admin.auth.login", {"email": email, "password": password})
    assert response.status_code == 200, response.text
    return response.json()


def test_admin_rest_login_and_me() -> None:
    admin = _bootstrap_admin()

    with TestClient(app) as client:
        login = client.post(
            "/api/v1/admin/auth/login",
            json={"email": admin["email"], "password": admin["password"]},
        )

        assert login.status_code == 200, login.text
        payload = login.json()
        assert payload["admin"]["email"] == admin["email"]
        assert payload["admin"]["displayName"] == admin["display_name"]
        assert payload["accessToken"]
        assert payload["refreshToken"]

        me = client.get(
            "/api/v1/admin/auth/me",
            headers={"Authorization": f"Bearer {payload['accessToken']}"},
        )

        assert me.status_code == 200, me.text
        assert me.json()["email"] == admin["email"]


def test_admin_rpc_auth_cycle_and_overview() -> None:
    admin = _bootstrap_admin()

    login_payload = _login_via_rpc(admin["email"], admin["password"])
    access_token = login_payload["accessToken"]
    refresh_token = login_payload["refreshToken"]

    me = _rpc("admin.auth.me", token=access_token)
    assert me.status_code == 200, me.text
    assert me.json()["email"] == admin["email"]

    overview = _rpc("admin.overview.get", token=access_token)
    assert overview.status_code == 200, overview.text
    overview_payload = overview.json()
    assert overview_payload["users"]["total"] == 0
    assert overview_payload["teams"]["total"] == 0
    assert overview_payload["tournaments"]["total"] == 0

    refreshed = _rpc("admin.auth.refresh", {"refreshToken": refresh_token})
    assert refreshed.status_code == 200, refreshed.text
    next_bundle = refreshed.json()
    assert next_bundle["accessToken"] != access_token

    logout = _rpc("admin.auth.logout", {"refreshToken": next_bundle["refreshToken"]})
    assert logout.status_code == 200, logout.text
    assert logout.json()["ok"] is True

    refresh_after_logout = _rpc(
        "admin.auth.refresh",
        {"refreshToken": next_bundle["refreshToken"]},
    )
    assert refresh_after_logout.status_code == 401, refresh_after_logout.text
    assert refresh_after_logout.json()["code"] == "ADMIN_UNAUTHORIZED"


def test_admin_rpc_crud_flow_for_users_teams_tournaments_and_matches() -> None:
    admin = _bootstrap_admin()
    bundle = _login_via_rpc(admin["email"], admin["password"])
    access_token = bundle["accessToken"]

    user_a = _rpc(
        "admin.users.create",
        {
            "public_id": "U300001",
            "nickname": "后台用户甲",
            "avatar_url": None,
            "status": 0,
        },
        access_token,
    )
    assert user_a.status_code == 200, user_a.text
    user_a_payload = user_a.json()

    user_b = _rpc(
        "admin.users.create",
        {
            "public_id": "U300002",
            "nickname": "后台用户乙",
            "avatar_url": None,
            "status": 0,
        },
        access_token,
    )
    assert user_b.status_code == 200, user_b.text
    user_b_payload = user_b.json()

    user_c = _rpc(
        "admin.users.create",
        {
            "public_id": "U300003",
            "nickname": "后台用户丙",
            "avatar_url": None,
            "status": 0,
        },
        access_token,
    )
    assert user_c.status_code == 200, user_c.text
    user_c_payload = user_c.json()

    user_d = _rpc(
        "admin.users.create",
        {
            "public_id": "U300004",
            "nickname": "后台用户丁",
            "avatar_url": None,
            "status": 0,
        },
        access_token,
    )
    assert user_d.status_code == 200, user_d.text
    user_d_payload = user_d.json()

    users_list = _rpc(
        "admin.users.list",
        {"q": "后台用户", "status": "all"},
        access_token,
    )
    assert users_list.status_code == 200, users_list.text
    assert len(users_list.json()["items"]) == 4

    user_detail = _rpc("admin.users.detail", {"id": user_a_payload["id"]}, access_token)
    assert user_detail.status_code == 200, user_detail.text
    assert user_detail.json()["publicId"] == "U300001"

    updated_user = _rpc(
        "admin.users.update",
        {
            "id": user_a_payload["id"],
            "nickname": "后台用户甲-更新",
            "avatar_url": None,
            "status": 2,
        },
        access_token,
    )
    assert updated_user.status_code == 200, updated_user.text
    assert updated_user.json()["nickname"] == "后台用户甲-更新"
    assert updated_user.json()["status"] == 2

    team_a = _rpc(
        "admin.teams.create",
        {
            "owner_id": user_a_payload["id"],
            "name": "Alpha 队",
            "intro": "A 队简介",
            "avatar_url": None,
            "status": 0,
        },
        access_token,
    )
    assert team_a.status_code == 200, team_a.text
    team_a_payload = team_a.json()

    team_b = _rpc(
        "admin.teams.create",
        {
            "owner_id": user_b_payload["id"],
            "name": "Beta 队",
            "intro": "B 队简介",
            "avatar_url": None,
            "status": 0,
        },
        access_token,
    )
    assert team_b.status_code == 200, team_b.text
    team_b_payload = team_b.json()

    teams_list = _rpc("admin.teams.list", {"q": "队", "status": "all"}, access_token)
    assert teams_list.status_code == 200, teams_list.text
    assert len(teams_list.json()["items"]) == 2

    team_detail = _rpc("admin.teams.detail", {"id": team_a_payload["id"]}, access_token)
    assert team_detail.status_code == 200, team_detail.text
    assert team_detail.json()["members"][0]["userId"] == user_a_payload["id"]

    with Session(engine) as session:
        session.add(
            TeamJoinRequest(
                team_id=team_a_payload["id"],
                applicant_user_id=user_c_payload["id"],
                personal_note="我想加入 Alpha 队",
                reason="补位",
                status="pending",
            )
        )
        session.add(
            TeamJoinRequest(
                team_id=team_a_payload["id"],
                applicant_user_id=user_d_payload["id"],
                personal_note="我也想加入 Alpha 队",
                reason="轮换",
                status="pending",
            )
        )
        session.commit()

    join_requests = _rpc(
        "admin.team_join_requests.list",
        {"team_id": team_a_payload["id"], "status": "pending"},
        access_token,
    )
    assert join_requests.status_code == 200, join_requests.text
    join_request_items = join_requests.json()["items"]
    assert len(join_request_items) == 2
    approve_request_id = next(
        item["id"] for item in join_request_items if item["applicantUserId"] == user_c_payload["id"]
    )
    reject_request_id = next(
        item["id"] for item in join_request_items if item["applicantUserId"] == user_d_payload["id"]
    )

    approved_request = _rpc(
        "admin.team_join_requests.approve",
        {"id": approve_request_id},
        access_token,
    )
    assert approved_request.status_code == 200, approved_request.text
    assert approved_request.json()["status"] == "approved"

    rejected_request = _rpc(
        "admin.team_join_requests.reject",
        {"id": reject_request_id},
        access_token,
    )
    assert rejected_request.status_code == 200, rejected_request.text
    assert rejected_request.json()["status"] == "rejected"

    refreshed_team_a = _rpc("admin.teams.detail", {"id": team_a_payload["id"]}, access_token)
    assert refreshed_team_a.status_code == 200, refreshed_team_a.text
    refreshed_team_a_payload = refreshed_team_a.json()
    approved_member = next(
        member for member in refreshed_team_a_payload["members"] if member["userId"] == user_c_payload["id"]
    )

    set_admin = _rpc(
        "admin.team_members.set_admin",
        {
            "team_id": team_a_payload["id"],
            "member_id": approved_member["id"],
            "is_admin": True,
        },
        access_token,
    )
    assert set_admin.status_code == 200, set_admin.text
    promoted_member = next(
        member for member in set_admin.json()["members"] if member["id"] == approved_member["id"]
    )
    assert promoted_member["role"] == 1

    transfer_owner = _rpc(
        "admin.team_members.transfer_owner",
        {
            "team_id": team_a_payload["id"],
            "member_id": approved_member["id"],
        },
        access_token,
    )
    assert transfer_owner.status_code == 200, transfer_owner.text
    assert transfer_owner.json()["ownerId"] == user_c_payload["id"]

    previous_owner_member = next(
        member for member in transfer_owner.json()["members"] if member["userId"] == user_a_payload["id"]
    )
    remove_member = _rpc(
        "admin.team_members.remove",
        {
            "team_id": team_a_payload["id"],
            "member_id": previous_owner_member["id"],
        },
        access_token,
    )
    assert remove_member.status_code == 200, remove_member.text
    assert all(
        member["userId"] != user_a_payload["id"] for member in remove_member.json()["members"]
    )

    updated_team = _rpc(
        "admin.teams.update",
        {
            "id": team_a_payload["id"],
            "name": "Alpha 队-更新",
            "intro": "更新后的简介",
            "avatar_url": None,
            "status": 1,
        },
        access_token,
    )
    assert updated_team.status_code == 200, updated_team.text
    assert updated_team.json()["name"] == "Alpha 队-更新"
    assert updated_team.json()["status"] == 1

    tournament = _rpc(
        "admin.tournaments.create",
        {
            "creator_id": user_a_payload["id"],
            "name": "春季赛",
            "intro": "春季邀请赛",
            "cover_url": None,
            "status": 0,
            "start_date": "2026-03-22",
            "end_date": "2026-03-23",
        },
        access_token,
    )
    assert tournament.status_code == 200, tournament.text
    tournament_payload = tournament.json()

    tournaments_list = _rpc("admin.tournaments.list", {"q": "春季", "status": "all"}, access_token)
    assert tournaments_list.status_code == 200, tournaments_list.text
    assert tournaments_list.json()["items"][0]["id"] == tournament_payload["id"]

    tournament_detail = _rpc(
        "admin.tournaments.detail",
        {"id": tournament_payload["id"]},
        access_token,
    )
    assert tournament_detail.status_code == 200, tournament_detail.text
    assert tournament_detail.json()["name"] == "春季赛"

    add_participant = _rpc(
        "admin.tournament_participants.add",
        {
            "tournament_id": tournament_payload["id"],
            "team_id": team_a_payload["id"],
        },
        access_token,
    )
    assert add_participant.status_code == 200, add_participant.text
    assert add_participant.json()["participants"][0]["teamId"] == team_a_payload["id"]

    tournament_participants = _rpc(
        "admin.tournament_participants.list",
        {"tournament_id": tournament_payload["id"]},
        access_token,
    )
    assert tournament_participants.status_code == 200, tournament_participants.text
    assert tournament_participants.json()["items"][0]["teamId"] == team_a_payload["id"]

    updated_tournament = _rpc(
        "admin.tournaments.update",
        {
            "id": tournament_payload["id"],
            "name": "春季赛-更新",
            "intro": "更新后的赛事简介",
            "cover_url": None,
            "status": 1,
            "start_date": "2026-03-24",
            "end_date": "2026-03-25",
        },
        access_token,
    )
    assert updated_tournament.status_code == 200, updated_tournament.text
    assert updated_tournament.json()["name"] == "春季赛-更新"
    assert updated_tournament.json()["status"] == 1

    start_time = datetime(2026, 3, 22, 10, 0, 0)
    end_time = start_time + timedelta(hours=2)
    match = _rpc(
        "admin.matches.create",
        {
            "tournament_id": tournament_payload["id"],
            "name": "第 1 轮",
            "topic": "人工智能利大于弊",
            "start_time": start_time.isoformat(),
            "end_time": end_time.isoformat(),
            "location": "一号厅",
            "format": "1v1",
            "opponent_team_name": None,
            "team_a_id": team_a_payload["id"],
            "team_b_id": team_b_payload["id"],
        },
        access_token,
    )
    assert match.status_code == 200, match.text
    match_payload = match.json()
    assert match_payload["teamAId"] == team_a_payload["id"]
    assert match_payload["teamBId"] == team_b_payload["id"]

    matches_list = _rpc(
        "admin.matches.list",
        {"tournament_id": tournament_payload["id"]},
        access_token,
    )
    assert matches_list.status_code == 200, matches_list.text
    assert matches_list.json()["items"][0]["id"] == match_payload["id"]

    match_detail = _rpc("admin.matches.detail", {"id": match_payload["id"]}, access_token)
    assert match_detail.status_code == 200, match_detail.text
    assert match_detail.json()["name"] == "第 1 轮"

    updated_match = _rpc(
        "admin.matches.update",
        {
            "id": match_payload["id"],
            "name": "第 1 轮-更新",
            "topic": "人工智能弊大于利",
            "start_time": (start_time + timedelta(days=1)).isoformat(),
            "end_time": (end_time + timedelta(days=1)).isoformat(),
            "location": "二号厅",
            "format": "1v1",
            "opponent_team_name": None,
            "team_a_id": team_a_payload["id"],
            "team_b_id": team_b_payload["id"],
        },
        access_token,
    )
    assert updated_match.status_code == 200, updated_match.text
    updated_match_payload = updated_match.json()
    assert updated_match_payload["name"] == "第 1 轮-更新"
    assert updated_match_payload["teamAId"] == team_a_payload["id"]
    assert updated_match_payload["teamBId"] == team_b_payload["id"]

    global_matches = _rpc(
        "admin.matches.list",
        {"q": "第 1 轮", "status": "scheduled", "team_id": team_a_payload["id"]},
        access_token,
    )
    assert global_matches.status_code == 200, global_matches.text
    assert global_matches.json()["items"][0]["id"] == match_payload["id"]

    team_a_roster = _rpc(
        "admin.match_rosters.update",
        {
            "match_id": match_payload["id"],
            "team_id": team_a_payload["id"],
            "assignments": [{"user_id": user_c_payload["id"], "position": "一辩"}],
        },
        access_token,
    )
    assert team_a_roster.status_code == 200, team_a_roster.text
    assert team_a_roster.json()["status"] == "scheduled"

    team_b_roster = _rpc(
        "admin.match_rosters.update",
        {
            "match_id": match_payload["id"],
            "team_id": team_b_payload["id"],
            "assignments": [{"user_id": user_b_payload["id"], "position": "一辩"}],
        },
        access_token,
    )
    assert team_b_roster.status_code == 200, team_b_roster.text
    assert team_b_roster.json()["status"] == "ready"

    advance_match = _rpc(
        "admin.matches.advance_status",
        {"match_id": match_payload["id"], "status": "ongoing"},
        access_token,
    )
    assert advance_match.status_code == 200, advance_match.text
    assert advance_match.json()["status"] == "ongoing"

    result_match = _rpc(
        "admin.match_results.update",
        {
            "match_id": match_payload["id"],
            "winner_team_id": team_a_payload["id"],
            "team_a_score": 3,
            "team_b_score": 1,
            "result_note": "Alpha 胜",
            "best_debater_position": "一辩",
        },
        access_token,
    )
    assert result_match.status_code == 200, result_match.text
    assert result_match.json()["status"] == "finished"
    assert result_match.json()["winnerTeamId"] == team_a_payload["id"]

    tournament_detail_after_match = _rpc(
        "admin.tournaments.detail",
        {"id": tournament_payload["id"]},
        access_token,
    )
    assert tournament_detail_after_match.status_code == 200, tournament_detail_after_match.text
    detail_payload = tournament_detail_after_match.json()
    assert len(detail_payload["participants"]) == 2
    assert len(detail_payload["matches"]) == 1

    beta_participant = next(
        participant for participant in detail_payload["participants"] if participant["teamId"] == team_b_payload["id"]
    )
    removed_participant = _rpc(
        "admin.tournament_participants.remove",
        {
            "tournament_id": tournament_payload["id"],
            "participant_id": beta_participant["id"],
        },
        access_token,
    )
    assert removed_participant.status_code == 200, removed_participant.text
    assert len(removed_participant.json()["participants"]) == 1
    assert removed_participant.json()["matches"][0]["teamBId"] is None

    deleted_match = _rpc("admin.matches.delete", {"id": match_payload["id"]}, access_token)
    assert deleted_match.status_code == 200, deleted_match.text
    assert deleted_match.json()["resourceId"] == match_payload["id"]

    deleted_tournament = _rpc(
        "admin.tournaments.delete",
        {"id": tournament_payload["id"]},
        access_token,
    )
    assert deleted_tournament.status_code == 200, deleted_tournament.text

    deleted_team_b = _rpc("admin.teams.delete", {"id": team_b_payload["id"]}, access_token)
    assert deleted_team_b.status_code == 200, deleted_team_b.text

    deleted_team_a = _rpc("admin.teams.delete", {"id": team_a_payload["id"]}, access_token)
    assert deleted_team_a.status_code == 200, deleted_team_a.text

    deleted_user_b = _rpc("admin.users.delete", {"id": user_b_payload["id"]}, access_token)
    assert deleted_user_b.status_code == 200, deleted_user_b.text

    deleted_user_d = _rpc("admin.users.delete", {"id": user_d_payload["id"]}, access_token)
    assert deleted_user_d.status_code == 200, deleted_user_d.text

    deleted_user_c = _rpc("admin.users.delete", {"id": user_c_payload["id"]}, access_token)
    assert deleted_user_c.status_code == 200, deleted_user_c.text

    deleted_user_a = _rpc("admin.users.delete", {"id": user_a_payload["id"]}, access_token)
    assert deleted_user_a.status_code == 200, deleted_user_a.text

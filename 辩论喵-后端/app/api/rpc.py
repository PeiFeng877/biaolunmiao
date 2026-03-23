from collections.abc import Mapping
from dataclasses import dataclass
from typing import Any

import httpx
from fastapi import APIRouter, Request, Response

from app.core.config import get_settings
from app.core.error_codes import ErrorCode
from app.core.exceptions import AppException
from app.core.responses import error_response
from app.schemas.rpc import RpcRequestIn

rpc_router = APIRouter()


@dataclass(frozen=True)
class ForwardSpec:
    path: str
    method: str = "GET"
    body: dict[str, Any] | None = None
    query: dict[str, str] | None = None


def _trimmed_string(value: Any, field_name: str, required: bool = False) -> str | None:
    if value is None:
        if required:
            raise AppException(ErrorCode.VALIDATION_ERROR, f"{field_name} 不能为空", 422)
        return None
    if not isinstance(value, str):
        raise AppException(ErrorCode.VALIDATION_ERROR, f"{field_name} 必须是字符串", 422)
    text = value.strip()
    if not text:
        if required:
            raise AppException(ErrorCode.VALIDATION_ERROR, f"{field_name} 不能为空", 422)
        return None
    return text


def _bool_value(value: Any, field_name: str, required: bool = False) -> bool | None:
    if value is None:
        if required:
            raise AppException(ErrorCode.VALIDATION_ERROR, f"{field_name} 不能为空", 422)
        return None
    if isinstance(value, bool):
        return value
    raise AppException(ErrorCode.VALIDATION_ERROR, f"{field_name} 必须是布尔值", 422)


def _query_value(value: Any) -> str | None:
    if value is None:
        return None
    if isinstance(value, bool):
        return "true" if value else "false"
    if isinstance(value, (int, float)):
        return str(value)
    if isinstance(value, str):
        text = value.strip()
        return text or None
    raise AppException(ErrorCode.VALIDATION_ERROR, "query 参数类型不支持", 422)


def _without_keys(values: Mapping[str, Any], *keys: str) -> dict[str, Any]:
    return {key: value for key, value in values.items() if key not in keys}


def _query_params(params: Mapping[str, Any], *keys: str) -> dict[str, str]:
    output: dict[str, str] = {}
    for key in keys:
        value = _query_value(params.get(key))
        if value is not None:
            output[key] = value
    return output


def _status_query_params(params: Mapping[str, Any], *keys: str) -> dict[str, str]:
    output = _query_params(params, *[key for key in keys if key != "status"])
    status = _query_value(params.get("status"))
    if status not in {None, "all"}:
        output["status"] = status
    return output


def _forward_spec(action: str, params: dict[str, Any]) -> ForwardSpec:
    prefix = get_settings().api_v1_prefix.rstrip("/")

    if action == "auth.debug_token":
        return ForwardSpec(f"{prefix}/auth/debug-token", method="POST", body=params)
    if action == "auth.apple.sign_in":
        return ForwardSpec(f"{prefix}/auth/apple", method="POST", body=params)
    if action == "auth.phone.send_code":
        return ForwardSpec(f"{prefix}/auth/phone/send-code", method="POST", body=params)
    if action == "auth.phone.sign_in":
        return ForwardSpec(f"{prefix}/auth/phone/sign-in", method="POST", body=params)
    if action == "auth.refresh":
        return ForwardSpec(f"{prefix}/auth/refresh", method="POST", body=params)
    if action == "account.delete":
        return ForwardSpec(f"{prefix}/account", method="DELETE")
    if action == "users.me.get":
        return ForwardSpec(f"{prefix}/users/me")
    if action == "users.me.update":
        return ForwardSpec(f"{prefix}/users/me", method="PUT", body=params)
    if action == "users.search":
        return ForwardSpec(f"{prefix}/users/search", query=_query_params(params, "q", "cursor", "limit"))
    if action == "teams.create":
        return ForwardSpec(f"{prefix}/teams", method="POST", body=params)
    if action == "teams.my.list":
        return ForwardSpec(f"{prefix}/teams/my", query=_query_params(params, "cursor", "limit"))
    if action == "teams.discover.list":
        return ForwardSpec(f"{prefix}/teams/discover", query=_query_params(params, "q", "cursor", "limit"))
    if action == "teams.detail.get":
        team_id = _trimmed_string(params.get("team_id"), "team_id", required=True)
        return ForwardSpec(f"{prefix}/teams/{team_id}")
    if action == "teams.update":
        team_id = _trimmed_string(params.get("team_id"), "team_id", required=True)
        return ForwardSpec(
            f"{prefix}/teams/{team_id}",
            method="PUT",
            body=_without_keys(params, "team_id"),
        )
    if action == "teams.dissolve":
        team_id = _trimmed_string(params.get("team_id"), "team_id", required=True)
        return ForwardSpec(f"{prefix}/teams/{team_id}:dissolve", method="POST")
    if action == "teams.transfer_owner":
        team_id = _trimmed_string(params.get("team_id"), "team_id", required=True)
        member_id = _trimmed_string(params.get("member_id"), "member_id", required=True)
        return ForwardSpec(
            f"{prefix}/teams/{team_id}:transfer-owner",
            method="POST",
            body={"memberId": member_id},
        )
    if action == "teams.member.toggle_admin":
        team_id = _trimmed_string(params.get("team_id"), "team_id", required=True)
        member_id = _trimmed_string(params.get("member_id"), "member_id", required=True)
        return ForwardSpec(f"{prefix}/teams/{team_id}/members/{member_id}:toggle-admin", method="POST")
    if action == "teams.member.remove":
        team_id = _trimmed_string(params.get("team_id"), "team_id", required=True)
        member_id = _trimmed_string(params.get("member_id"), "member_id", required=True)
        return ForwardSpec(f"{prefix}/teams/{team_id}/members/{member_id}", method="DELETE")
    if action == "teams.join_request.submit":
        team_id = _trimmed_string(params.get("team_id"), "team_id", required=True)
        body = {
            "personal_note": _trimmed_string(params.get("personal_note"), "personal_note", required=True),
            "reason": _trimmed_string(params.get("reason"), "reason"),
        }
        return ForwardSpec(f"{prefix}/teams/{team_id}/join-requests", method="POST", body=body)
    if action == "teams.join_request.review":
        request_id = _trimmed_string(params.get("request_id"), "request_id", required=True)
        approve = _bool_value(params.get("approve"), "approve", required=True)
        decision = "approve" if approve else "reject"
        return ForwardSpec(f"{prefix}/teams/join-requests/{request_id}:{decision}", method="POST")
    if action == "teams.join_requests.list":
        return ForwardSpec(
            f"{prefix}/teams/join-requests",
            query=_query_params(params, "scope", "status", "cursor", "limit"),
        )
    if action == "tournaments.list":
        return ForwardSpec(f"{prefix}/tournaments", query=_query_params(params, "cursor", "limit"))
    if action == "tournaments.detail.get":
        tournament_id = _trimmed_string(params.get("tournament_id"), "tournament_id", required=True)
        return ForwardSpec(f"{prefix}/tournaments/{tournament_id}")
    if action == "tournaments.create":
        return ForwardSpec(f"{prefix}/tournaments", method="POST", body=params)
    if action == "tournaments.update":
        tournament_id = _trimmed_string(params.get("tournament_id"), "tournament_id", required=True)
        return ForwardSpec(
            f"{prefix}/tournaments/{tournament_id}",
            method="PUT",
            body=_without_keys(params, "tournament_id"),
        )
    if action == "tournaments.matches.list":
        tournament_id = _trimmed_string(params.get("tournament_id"), "tournament_id", required=True)
        return ForwardSpec(
            f"{prefix}/tournaments/{tournament_id}/matches",
            query=_query_params(params, "cursor", "limit"),
        )
    if action == "matches.create":
        tournament_id = _trimmed_string(params.get("tournament_id"), "tournament_id", required=True)
        return ForwardSpec(
            f"{prefix}/tournaments/{tournament_id}/matches",
            method="POST",
            body=_without_keys(params, "tournament_id"),
        )
    if action == "matches.update":
        match_id = _trimmed_string(params.get("match_id"), "match_id", required=True)
        return ForwardSpec(
            f"{prefix}/tournaments/matches/{match_id}",
            method="PUT",
            body=_without_keys(params, "match_id"),
        )
    if action == "matches.assign_teams":
        match_id = _trimmed_string(params.get("match_id"), "match_id", required=True)
        return ForwardSpec(
            f"{prefix}/tournaments/matches/{match_id}:assign-teams",
            method="POST",
            body=_without_keys(params, "match_id"),
        )
    if action == "matches.roster.save":
        match_id = _trimmed_string(params.get("match_id"), "match_id", required=True)
        team_id = _trimmed_string(params.get("team_id"), "team_id", required=True)
        return ForwardSpec(
            f"{prefix}/tournaments/matches/{match_id}/rosters/{team_id}",
            method="PUT",
            body={"assignments": params.get("assignments", [])},
        )
    if action == "matches.advance_status":
        match_id = _trimmed_string(params.get("match_id"), "match_id", required=True)
        return ForwardSpec(
            f"{prefix}/tournaments/matches/{match_id}:advance-status",
            method="POST",
            body=_without_keys(params, "match_id"),
        )
    if action == "matches.result.record":
        match_id = _trimmed_string(params.get("match_id"), "match_id", required=True)
        return ForwardSpec(
            f"{prefix}/tournaments/matches/{match_id}/result",
            method="PUT",
            body=_without_keys(params, "match_id"),
        )
    if action == "messages.list":
        return ForwardSpec(f"{prefix}/messages", query=_query_params(params, "cursor", "limit"))
    if action == "messages.ack":
        message_id = _trimmed_string(params.get("message_id"), "message_id", required=True)
        return ForwardSpec(f"{prefix}/messages/{message_id}:ack", method="POST")
    if action == "schedule.list":
        return ForwardSpec(f"{prefix}/schedule", query=_query_params(params, "from", "to", "cursor", "limit"))
    if action == "schedule.sources.list":
        return ForwardSpec(f"{prefix}/schedule/sources")
    if action == "schedule.sources.create":
        return ForwardSpec(f"{prefix}/schedule/sources", method="POST", body=params)
    if action == "schedule.sources.toggle":
        source_id = _trimmed_string(params.get("source_id"), "source_id", required=True)
        is_enabled = _bool_value(params.get("is_enabled"), "is_enabled", required=True)
        return ForwardSpec(
            f"{prefix}/schedule/sources/{source_id}",
            method="PUT",
            body={"is_enabled": is_enabled},
        )
    if action == "schedule.sources.delete":
        source_id = _trimmed_string(params.get("source_id"), "source_id", required=True)
        return ForwardSpec(f"{prefix}/schedule/sources/{source_id}", method="DELETE")
    if action == "media.avatar_upload_token":
        return ForwardSpec(f"{prefix}/media/avatar-upload-token", method="POST", body=params)
    if action == "media.cover_upload_token":
        return ForwardSpec(f"{prefix}/media/cover-upload-token", method="POST", body=params)
    if action == "admin.auth.login":
        return ForwardSpec(f"{prefix}/admin/auth/login", method="POST", body=params)
    if action == "admin.auth.refresh":
        return ForwardSpec(f"{prefix}/admin/auth/refresh", method="POST", body=params)
    if action == "admin.auth.logout":
        return ForwardSpec(f"{prefix}/admin/auth/logout", method="POST", body=params)
    if action == "admin.auth.me":
        return ForwardSpec(f"{prefix}/admin/auth/me")
    if action == "admin.overview.get":
        return ForwardSpec(f"{prefix}/admin/overview")
    if action == "admin.users.list":
        return ForwardSpec(
            f"{prefix}/admin/users",
            query=_status_query_params(params, "q", "status", "cursor", "limit"),
        )
    if action == "admin.users.detail":
        user_id = _trimmed_string(params.get("id"), "id", required=True)
        return ForwardSpec(f"{prefix}/admin/users/{user_id}")
    if action == "admin.users.create":
        return ForwardSpec(f"{prefix}/admin/users", method="POST", body=params)
    if action == "admin.users.update":
        user_id = _trimmed_string(params.get("id"), "id", required=True)
        return ForwardSpec(
            f"{prefix}/admin/users/{user_id}",
            method="PATCH",
            body=_without_keys(params, "id"),
        )
    if action == "admin.users.delete":
        user_id = _trimmed_string(params.get("id"), "id", required=True)
        return ForwardSpec(f"{prefix}/admin/users/{user_id}", method="DELETE")
    if action == "admin.teams.list":
        return ForwardSpec(
            f"{prefix}/admin/teams",
            query=_status_query_params(params, "q", "status", "cursor", "limit"),
        )
    if action == "admin.teams.detail":
        team_id = _trimmed_string(params.get("id"), "id", required=True)
        return ForwardSpec(f"{prefix}/admin/teams/{team_id}")
    if action == "admin.teams.create":
        return ForwardSpec(f"{prefix}/admin/teams", method="POST", body=params)
    if action == "admin.teams.update":
        team_id = _trimmed_string(params.get("id"), "id", required=True)
        return ForwardSpec(
            f"{prefix}/admin/teams/{team_id}",
            method="PATCH",
            body=_without_keys(params, "id"),
        )
    if action == "admin.teams.delete":
        team_id = _trimmed_string(params.get("id"), "id", required=True)
        return ForwardSpec(f"{prefix}/admin/teams/{team_id}", method="DELETE")
    if action == "admin.team_join_requests.list":
        return ForwardSpec(
            f"{prefix}/admin/team-join-requests",
            query=_query_params(params, "team_id", "applicant_user_id", "status", "q", "cursor", "limit"),
        )
    if action == "admin.team_join_requests.approve":
        request_id = _trimmed_string(params.get("id"), "id", required=True)
        return ForwardSpec(f"{prefix}/admin/team-join-requests/{request_id}:approve", method="POST")
    if action == "admin.team_join_requests.reject":
        request_id = _trimmed_string(params.get("id"), "id", required=True)
        return ForwardSpec(f"{prefix}/admin/team-join-requests/{request_id}:reject", method="POST")
    if action == "admin.team_members.add":
        team_id = _trimmed_string(params.get("team_id"), "team_id", required=True)
        return ForwardSpec(
            f"{prefix}/admin/teams/{team_id}/members",
            method="POST",
            body=_without_keys(params, "team_id"),
        )
    if action == "admin.team_members.set_admin":
        team_id = _trimmed_string(params.get("team_id"), "team_id", required=True)
        member_id = _trimmed_string(params.get("member_id"), "member_id", required=True)
        is_admin = _bool_value(params.get("is_admin"), "is_admin", required=True)
        return ForwardSpec(
            f"{prefix}/admin/teams/{team_id}/members/{member_id}:set-admin",
            method="POST",
            body={"is_admin": is_admin},
        )
    if action == "admin.team_members.transfer_owner":
        team_id = _trimmed_string(params.get("team_id"), "team_id", required=True)
        member_id = _trimmed_string(params.get("member_id"), "member_id", required=True)
        return ForwardSpec(
            f"{prefix}/admin/teams/{team_id}:transfer-owner",
            method="POST",
            body={"member_id": member_id},
        )
    if action == "admin.team_members.remove":
        team_id = _trimmed_string(params.get("team_id"), "team_id", required=True)
        member_id = _trimmed_string(params.get("member_id"), "member_id", required=True)
        return ForwardSpec(f"{prefix}/admin/teams/{team_id}/members/{member_id}", method="DELETE")
    if action == "admin.tournaments.list":
        return ForwardSpec(
            f"{prefix}/admin/tournaments",
            query=_status_query_params(params, "q", "status", "cursor", "limit"),
        )
    if action == "admin.tournaments.detail":
        tournament_id = _trimmed_string(params.get("id"), "id", required=True)
        return ForwardSpec(f"{prefix}/admin/tournaments/{tournament_id}")
    if action == "admin.tournaments.create":
        return ForwardSpec(f"{prefix}/admin/tournaments", method="POST", body=params)
    if action == "admin.tournaments.update":
        tournament_id = _trimmed_string(params.get("id"), "id", required=True)
        return ForwardSpec(
            f"{prefix}/admin/tournaments/{tournament_id}",
            method="PATCH",
            body=_without_keys(params, "id"),
        )
    if action == "admin.tournaments.delete":
        tournament_id = _trimmed_string(params.get("id"), "id", required=True)
        return ForwardSpec(f"{prefix}/admin/tournaments/{tournament_id}", method="DELETE")
    if action == "admin.tournament_participants.list":
        tournament_id = _trimmed_string(params.get("tournament_id"), "tournament_id", required=True)
        return ForwardSpec(
            f"{prefix}/admin/tournaments/{tournament_id}/participants",
            query=_query_params(params, "cursor", "limit"),
        )
    if action == "admin.tournament_participants.add":
        tournament_id = _trimmed_string(params.get("tournament_id"), "tournament_id", required=True)
        return ForwardSpec(
            f"{prefix}/admin/tournaments/{tournament_id}/participants",
            method="POST",
            body=_without_keys(params, "tournament_id"),
        )
    if action == "admin.tournament_participants.remove":
        tournament_id = _trimmed_string(params.get("tournament_id"), "tournament_id", required=True)
        participant_id = _trimmed_string(params.get("participant_id"), "participant_id", required=True)
        return ForwardSpec(
            f"{prefix}/admin/tournaments/{tournament_id}/participants/{participant_id}",
            method="DELETE",
        )
    if action == "admin.matches.list":
        tournament_id = _trimmed_string(params.get("tournament_id"), "tournament_id")
        match_query = _query_params(params, "q", "status", "team_id", "cursor", "limit")
        if tournament_id is None:
            return ForwardSpec(f"{prefix}/admin/matches", query=match_query)
        return ForwardSpec(
            f"{prefix}/admin/tournaments/{tournament_id}/matches",
            query=match_query,
        )
    if action == "admin.matches.detail":
        match_id = _trimmed_string(params.get("id"), "id", required=True)
        return ForwardSpec(f"{prefix}/admin/matches/{match_id}")
    if action == "admin.matches.create":
        tournament_id = _trimmed_string(params.get("tournament_id"), "tournament_id", required=True)
        return ForwardSpec(
            f"{prefix}/admin/tournaments/{tournament_id}/matches",
            method="POST",
            body=_without_keys(params, "tournament_id"),
        )
    if action == "admin.matches.update":
        match_id = _trimmed_string(params.get("id"), "id", required=True)
        return ForwardSpec(
            f"{prefix}/admin/matches/{match_id}",
            method="PATCH",
            body=_without_keys(params, "id"),
        )
    if action == "admin.matches.delete":
        match_id = _trimmed_string(params.get("id"), "id", required=True)
        return ForwardSpec(f"{prefix}/admin/matches/{match_id}", method="DELETE")
    if action == "admin.match_rosters.update":
        match_id = _trimmed_string(params.get("match_id"), "match_id", required=True)
        team_id = _trimmed_string(params.get("team_id"), "team_id", required=True)
        return ForwardSpec(
            f"{prefix}/admin/matches/{match_id}/rosters/{team_id}",
            method="PUT",
            body={"assignments": params.get("assignments", [])},
        )
    if action == "admin.match_results.update":
        match_id = _trimmed_string(params.get("match_id"), "match_id", required=True)
        return ForwardSpec(
            f"{prefix}/admin/matches/{match_id}/result",
            method="PUT",
            body=_without_keys(params, "match_id"),
        )
    if action == "admin.matches.advance_status":
        match_id = _trimmed_string(params.get("match_id"), "match_id", required=True)
        return ForwardSpec(
            f"{prefix}/admin/matches/{match_id}:advance-status",
            method="POST",
            body=_without_keys(params, "match_id"),
        )

    raise AppException(ErrorCode.NOT_FOUND, f"未知 action: {action}", 404)


@rpc_router.post("/api")
async def rpc_entry(request: Request, payload: RpcRequestIn):
    action = payload.action.strip()
    request_id = payload.request_id.strip() if payload.request_id else request.state.request_id
    request.state.request_id = request_id
    if not action:
        return error_response(
            code=ErrorCode.VALIDATION_ERROR,
            message="action 不能为空",
            request_id=request_id,
            status_code=422,
        )

    spec = _forward_spec(action, payload.params)
    headers = dict(request.headers)
    headers["x-request-id"] = request_id
    headers["x-blm-public-base-url"] = str(request.base_url)

    async with httpx.AsyncClient(
        transport=httpx.ASGITransport(app=request.app),
        base_url="http://rpc.local",
    ) as client:
        response = await client.request(
            spec.method,
            spec.path,
            params=spec.query,
            json=spec.body,
            headers=headers,
        )

    passthrough_headers = {
        key: value for key, value in response.headers.items() if key.lower() == "content-type"
    }
    return Response(
        content=response.content,
        status_code=response.status_code,
        headers=passthrough_headers,
    )

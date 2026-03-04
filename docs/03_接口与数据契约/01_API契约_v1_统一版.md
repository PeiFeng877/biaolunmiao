# API 契约 v1（统一版）

[PROTOCOL]: 变更时更新此头部，然后检查 agents.md

**版本**: v1.2
**日期**: 2026-03-04


## 1. 全局约定

- Base URL: `/api/v1`
- Auth: `Authorization: Bearer <access_token>`
- 写接口返回最新对象快照
- 列表返回：`{ items, nextCursor }`
- 错误返回：`{ code, message, requestId, details? }`

## 2. Auth

- `POST /auth/apple`
  - 返回新增 `isNewUser: boolean`
  - 语义: 仅在本次 Apple 登录首次创建用户时返回 `true`，其余情况返回 `false`
- `POST /auth/refresh`
- `POST /auth/debug-token`（仅非 prod）
- `POST /auth/debug-token` 入参约束：`public_id` 长度 `1~20`，`nickname` 长度 `1~50`

## 3. Users

- `GET /users/me`
- `PUT /users/me`
- `GET /users/search?q=&cursor=&limit=`

## 4. Teams

- `POST /teams`
- `GET /teams/my`
- `GET /teams/discover`
- `GET /teams/{teamId}`
- `PUT /teams/{teamId}`
- `POST /teams/{teamId}/join-requests`
- `POST /teams/join-requests/{requestId}:approve`
- `POST /teams/join-requests/{requestId}:reject`
- `POST /teams/{teamId}:transfer-owner`
- `POST /teams/{teamId}/members/{memberId}:toggle-admin`
- `DELETE /teams/{teamId}/members/{memberId}`
- `POST /teams/{teamId}:dissolve`

## 5. Tournaments / Matches

- `POST /tournaments`
- `GET /tournaments`
- `GET /tournaments/{tournamentId}`
- `PUT /tournaments/{tournamentId}`
- `POST /tournaments/{tournamentId}/matches`
- `PUT /tournaments/matches/{matchId}`
- `POST /tournaments/matches/{matchId}:assign-teams`
- `PUT /tournaments/matches/{matchId}/rosters/{teamId}`
- `POST /tournaments/matches/{matchId}:advance-status`
- `PUT /tournaments/matches/{matchId}/result`

## 6. Schedule

- `GET /schedule?from=...&to=...`
- `GET /schedule/sources`
- `POST /schedule/sources`
- `PUT /schedule/sources/{sourceId}`
- `DELETE /schedule/sources/{sourceId}`

## 7. Messages

- `GET /messages`
- `POST /messages/{messageId}:ack`

## 8. Media

- `POST /media/avatar-upload-token`
- `POST /media/cover-upload-token`

## 9. 关键错误码

- `TEAM_ROLE_FORBIDDEN`
- `DUPLICATE_PENDING_REQUEST`
- `MATCH_STATUS_INVALID_TRANSITION`
- `ROSTER_INVALID_MEMBER`
- `ROSTER_INVALID_POSITION`
- `INVALID_TOKEN`

## 变更日志
- 2026-03-04: `POST /auth/apple` 响应新增 `isNewUser`，用于客户端登录后首登资料完善分流。
- 2026-02-20: 补充 `POST /auth/debug-token` 的入参长度约束，避免越界写入导致 500。
- 2026-02-17: 迁移并纳入根目录统一文档体系。

# API 契约 v1（统一版）

[PROTOCOL]: 变更时更新此头部，然后检查 agents.md

**版本**: v1.9
**日期**: 2026-03-22


## 1. 全局约定

- Health Check: `GET /healthz`
- Business Entry: `POST /api`
- Auth: `Authorization: Bearer <access_token>`
- RPC 请求体：`{ action: string, params?: object, request_id?: string }`
- 写接口返回最新对象快照
- 列表返回：`{ items, nextCursor }`
- 错误返回：`{ code, message, requestId, details? }`
- 现行部署形态为 `FC Web 函数 + FastAPI`，不再暴露 `/api/v1/**`。

## 2. Auth

- `auth.apple.sign_in`
  - 返回新增 `isNewUser: boolean`
  - 语义: 仅在本次 Apple 登录首次创建用户时返回 `true`，其余情况返回 `false`
  - 若同一 Apple 账号命中过往已删除账号：创建全新账号并返回 `isNewUser = true`
  - 新账号不继承旧账号的队伍、赛事、消息、日程等历史数据
  - 本地开发允许占位联调策略，正式环境必须执行正式 Apple 校验
  - 正式环境校验项固定包括：`issuer`、`audience`、`exp`、`sub`、`kid` 与签名
- `auth.refresh`
- `auth.debug_token`（仅非 prod）
- `auth.debug_token` 入参约束：`public_id` 长度 `1~20`，`nickname` 长度 `1~50`
- `auth.debug_token` 在 `prod` 的固定失败契约：`403 DEBUG_TOKEN_DISABLED`

## 3. Account

- `account.delete`
  - 语义: 将当前登录账号标记为 `deleted`
  - 响应字段: `ok`、`status`、`deletedAt`
  - 副作用: 立即撤销当前账号全部 refresh token
  - 副作用: 释放当前账号的 `apple_sub` 绑定，允许同一 Apple 账号重新注册新账号
  - 删除后同一 Apple 账号再次登录: 创建新账号，不恢复旧账号

## 4. Users

- `users.me.get`
- `users.me.update`
- `users.search`
  - 对 `deleted` 账号: 受保护接口返回 `ACCOUNT_DELETED`

## 5. Teams

- `teams.create`
- `teams.my.list`
- `teams.discover.list`
- `teams.detail.get`
- `teams.update`
- `teams.join_request.submit`
- `teams.join_request.review`
- `teams.transfer_owner`
- `teams.member.toggle_admin`
- `teams.member.remove`
- `teams.dissolve`

## 6. Tournaments / Matches

- `tournaments.create`
- `tournaments.list`
- `tournaments.detail.get`
- `tournaments.update`
- `tournaments.matches.list`
- `matches.create`
- `matches.update`
- `matches.assign_teams`
- `matches.roster.save`
- `matches.advance_status`
- `matches.result.record`

## 7. Schedule

- `schedule.list`
- `schedule.sources.list`
- `schedule.sources.create`
- `schedule.sources.toggle`
- `schedule.sources.delete`

## 8. Messages

- `messages.list`
- `messages.ack`

## 9. Media

- `media.avatar_upload_token`
- `media.cover_upload_token`
  - 返回字段保持 `objectKey`、`uploadUrl`、`expiresAt`、`method`、`uploadHeaders`、`publicUrl`、`provider`
  - `objectKey` 语义固定为提供方最终落库的对象 key；本地开发可返回本地 mock 目标，正式环境统一由 `OSS` 承载
  - `provider` 兼容历史 `oss`，本地开发可使用 mock provider，但字段结构必须保持兼容

## 10. 关键错误码

- `TEAM_ROLE_FORBIDDEN`
- `DUPLICATE_PENDING_REQUEST`
- `MATCH_STATUS_INVALID_TRANSITION`
- `ROSTER_INVALID_MEMBER`
- `ROSTER_INVALID_POSITION`
- `INVALID_TOKEN`
- `ACCOUNT_DELETED`
- `DEBUG_TOKEN_DISABLED`
- `APPLE_TOKEN_INVALID`

## 变更日志
- 2026-03-22: 明确现行部署形态为 `FC Web 函数 + FastAPI`，移除 `admin.*` 现行契约与 `/api/v1/**` 口径。
- 2026-03-22: 正式环境与 `TestFlight` 共用同一套 App API 契约，媒体 provider 统一以 `OSS` 为主、本地开发可用 mock provider。
- 2026-03-10: 调整账号删除后 Apple 登录语义；同一 Apple 账号可重新注册新账号，旧账号保持 `deleted` 且历史数据不迁移。
- 2026-03-06: 新增 `DELETE /account` 契约，明确软删除、刷新令牌撤销与 `ACCOUNT_DELETED` 语义。
- 2026-03-04: `POST /auth/apple` 响应新增 `isNewUser`，用于客户端登录后首登资料完善分流。
- 2026-02-20: 补充 `POST /auth/debug-token` 的入参长度约束，避免越界写入导致 500。
- 2026-02-17: 迁移并纳入根目录统一文档体系。

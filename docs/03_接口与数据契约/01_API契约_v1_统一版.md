# API 契约 v1（统一版）

[PROTOCOL]: 变更时更新此头部，然后检查 agents.md

**版本**: v1.16
**日期**: 2026-03-23


## 1. 全局约定

- Health Check: `GET /healthz`
- Business Entry: `POST /api`
- Auth: `Authorization: Bearer <access_token>`
- RPC 请求体：`{ action: string, params?: object, request_id?: string }`
- 写接口返回最新对象快照
- 列表返回：`{ items, nextCursor }`
- 错误返回：`{ code, message, requestId, details? }`
- 现行部署形态为 `FC Web 函数 + FastAPI`，对外统一入口仍为 `GET /healthz` 与 `POST /api`；`/api/v1/**` 仅保留为服务内兼容与测试入口。

## 2. Auth

- `auth.apple.sign_in`
  - 返回新增 `isNewUser: boolean`
  - 语义: 仅在本次 Apple 登录首次创建用户时返回 `true`，其余情况返回 `false`
  - 若同一 Apple 账号命中过往已删除账号：创建全新账号并返回 `isNewUser = true`
  - 新账号不继承旧账号的队伍、赛事、消息、日程等历史数据
  - 本地开发允许占位联调策略，正式环境必须执行正式 Apple 校验
  - 正式环境校验项固定包括：`issuer`、`audience`、`exp`、`sub`、`kid` 与签名
- `auth.phone.send_code`
  - 入参: `phone`
  - 语义: 发送手机号验证码；本地开发可使用 mock provider，正式环境必须走阿里云号码认证服务的短信认证能力
  - 服务端负责生成 4 位验证码并持久化摘要，provider 仅负责短信下发，不再依赖 provider 二次核验作为登录成功判定
  - 手机号必须先标准化为中国大陆 E.164 格式，再进入发送与核验流程
- `auth.phone.sign_in`
  - 入参: `phone`、`code`
  - 语义: 校验服务端持久化的验证码摘要并完成手机号登录；成功后按手机号查找或创建用户，返回 `TokenBundleOut` 与 `isNewUser`
  - V1 不做手机号绑定、换绑，或与 Apple 账号的自动合并
- `auth.refresh`
- `auth.debug_token`（仅非 prod）
- `auth.debug_token` 入参约束：`public_id` 长度 `1~20`，`nickname` 长度 `1~50`
- `auth.debug_token` 在 `prod` 的固定失败契约：`403 DEBUG_TOKEN_DISABLED`

## 3. Account

- `account.delete`
  - 语义: 将当前登录账号标记为 `deleted`
  - 响应字段: `ok`、`status`、`deletedAt`
  - 副作用: 立即撤销当前账号全部 refresh token
  - 副作用: 释放当前账号关联的 Apple / 手机号身份绑定，允许同一 Apple 账号或同一手机号重新注册新账号
  - 删除后同一 Apple 账号或同一手机号再次登录: 创建新账号，不恢复旧账号

## 4. Users

- `users.me.get`
- `users.me.update`
- `users.search`
  - 对 `deleted` 账号: 受保护接口返回 `ACCOUNT_DELETED`

## 5. Teams

- `teams.create`
  - 响应队伍对象口径包含 `createdAt`
- `teams.my.list`
  - 响应队伍对象口径包含 `createdAt`
  - iOS 端据此对当前可管理队伍按创建时间升序排序，默认选中最早创建的一支
- `teams.discover.list`
  - 响应队伍对象口径包含 `createdAt`
- `teams.detail.get`
  - 响应队伍对象口径包含 `createdAt`
  - 响应成员对象新增 `displayName`，语义为该成员在当前队伍内使用的队内称呼；若成员未单独设置，则回退为账号全局昵称
- `teams.update`
- `teams.join_request.submit`
  - 入参 `personal_note` 的现行语义固定为“申请人希望在该队伍内使用的队内称呼”
  - 审批通过时，后端默认将该值写入成员 `displayName`
- `teams.join_request.review`
- `teams.member.update`
  - 入参: `team_id`、`member_id`、`display_name`
  - 权限: 成员本人可修改自己的队内称呼；队长可修改任意其他成员的队内称呼；管理员仅可修改普通队员的队内称呼
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

## 9. Admin Console

- Web 管理后台现行通过 `admin.*` action 走同一个 `POST /api` RPC 入口，不直连业务用户会话。
- `admin.auth.login`
- `admin.auth.refresh`
- `admin.auth.logout`
- `admin.auth.me`
- `admin.overview.get`
- `admin.users.list`
- `admin.users.detail`
- `admin.users.create`
- `admin.users.update`
- `admin.users.delete`
- `admin.teams.list`
- `admin.teams.detail`
- `admin.teams.create`
- `admin.teams.update`
- `admin.teams.delete`
- `admin.team_join_requests.list`
- `admin.team_join_requests.approve`
- `admin.team_join_requests.reject`
- `admin.team_members.add`
- `admin.team_members.set_admin`
- `admin.team_members.transfer_owner`
- `admin.team_members.remove`
- `admin.tournaments.list`
- `admin.tournaments.detail`
- `admin.tournaments.create`
- `admin.tournaments.update`
- `admin.tournaments.delete`
- `admin.tournament_participants.list`
- `admin.tournament_participants.add`
- `admin.tournament_participants.remove`
- `admin.matches.list`
- `admin.matches.detail`
- `admin.matches.create`
- `admin.matches.update`
- `admin.matches.delete`
- `admin.match_rosters.update`
- `admin.match_results.update`
- `admin.matches.advance_status`
- 场次创建/更新入参兼容 `team_a_id`、`team_b_id`，用于后台直接维护对阵关系；同一场次的 A/B 队伍不得相同。
- `admin.matches.list` 支持两种模式：带 `tournament_id` 时返回赛事内场次；不带 `tournament_id` 时支持按 `q`、`status`、`team_id` 全局筛选。
- 队伍详情响应现行包含 `members` 与 `joinRequests`；赛事详情响应包含带队伍标签的 `participants` 与 `matches`；场次详情响应包含赛事名、对阵队伍标签与富 roster 信息。

## 10. Media

- `media.avatar_upload_token`
- `media.cover_upload_token`
  - 返回字段保持 `objectKey`、`uploadUrl`、`expiresAt`、`method`、`uploadHeaders`、`publicUrl`、`provider`
  - `objectKey` 语义固定为提供方最终落库的对象 key；本地开发可返回本地 mock 目标，正式环境统一由 `OSS` 承载
  - `provider` 兼容历史 `oss`，本地开发可使用 mock provider，但字段结构必须保持兼容
  - 面向 iOS/正式客户端时，`uploadUrl` 与 `publicUrl` 必须返回可被 `ATS` 接受的 `https` 地址；禁止向正式客户端下发 `http` 媒体地址

## 11. 关键错误码

- `TEAM_ROLE_FORBIDDEN`
- `DUPLICATE_PENDING_REQUEST`
- `MATCH_TEAM_DUPLICATED`
- `MATCH_STATUS_INVALID_TRANSITION`
- `ROSTER_INVALID_MEMBER`
- `ROSTER_INVALID_POSITION`
- `ADMIN_UNAUTHORIZED`
- `ADMIN_EMAIL_PASSWORD_INVALID`
- `INVALID_TOKEN`
- `ACCOUNT_DELETED`
- `DEBUG_TOKEN_DISABLED`
- `APPLE_TOKEN_INVALID`
- `PHONE_INVALID`
- `PHONE_CODE_INVALID`
- `PHONE_CODE_EXPIRED`
- `PHONE_CODE_TOO_FREQUENT`
- `PHONE_AUTH_NOT_AVAILABLE`

## 变更日志
- 2026-03-23: 队伍成员对象新增 `displayName`，`teams.join_request.submit.personal_note` 语义收口为队内称呼，并新增 `teams.member.update` 用于成员队内称呼维护。
- 2026-03-23: 明确媒体上传 token 在正式客户端场景下必须返回 `https` 的 `uploadUrl/publicUrl`，避免 iOS `ATS` 拦截头像上传与回显。
- 2026-03-23: 队伍契约口径补齐 `createdAt` 说明，iOS 端据此完成多队场次编辑默认排序与回填。
- 2026-03-22: 手机号验证码链路改为服务端生成与本地摘要核验，阿里云号码认证仅承担短信下发能力。
- 2026-03-22: 后台 admin 契约扩展到入队申请审批、队伍成员管理、赛事参赛队伍管理、场次名单/赛果/状态推进，并明确 `admin.matches.list` 支持全局过滤模式。
- 2026-03-22: 恢复 Web 管理后台现行 `admin.*` RPC 契约，纳入用户/队伍/赛事/场次 CRUD 与管理员鉴权语义。
- 2026-03-22: 新增手机号验证码登录契约，统一补充 `auth.phone.send_code`、`auth.phone.sign_in` 与相关错误码。
- 2026-03-22: 明确现行部署形态为 `FC Web 函数 + FastAPI`，移除 `admin.*` 现行契约与 `/api/v1/**` 口径。
- 2026-03-22: 正式环境与 `TestFlight` 共用同一套 App API 契约，媒体 provider 统一以 `OSS` 为主、本地开发可用 mock provider。
- 2026-03-10: 调整账号删除后 Apple 登录语义；同一 Apple 账号可重新注册新账号，旧账号保持 `deleted` 且历史数据不迁移。
- 2026-03-06: 新增 `DELETE /account` 契约，明确软删除、刷新令牌撤销与 `ACCOUNT_DELETED` 语义。
- 2026-03-04: `POST /auth/apple` 响应新增 `isNewUser`，用于客户端登录后首登资料完善分流。
- 2026-02-20: 补充 `POST /auth/debug-token` 的入参长度约束，避免越界写入导致 500。
- 2026-02-17: 迁移并纳入根目录统一文档体系。

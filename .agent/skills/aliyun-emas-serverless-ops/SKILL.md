---
name: aliyun-emas-serverless-ops
description: 当在辩论喵单仓内需要通过阿里云 OpenAPI、aliyun CLI、OpenAPI MCP 或 Node SDK 管理 EMAS Serverless 的服务空间、云函数、HTTP 触发、CORS、serverSecret、云数据库与部署时使用。
---

# 阿里云 EMAS Serverless 自动化操作

[PROTOCOL]: 变更时更新此头部，然后检查 agents.md

**版本**: v1.12
**日期**: 2026-03-21
**适用范围**: `/Users/Icarus/Documents/project 2026/bianlunmiao`

仅在 `/Users/Icarus/Documents/project 2026/bianlunmiao` 内使用此 skill。

## 1. 目标
- 统一辩论喵仓库后续对 EMAS Serverless 的自动化操作入口。
- 优先使用官方控制面 SDK `@alicloud/mpserverless20190615` 管控制面资源。
- `aliyun` CLI 只承担 profile 管理与 `sts GetCallerIdentity` 身份校验。
- 运行时能力优先使用 Node SDK。
- 若需要 Agent 化远程操作，优先走阿里云 OpenAPI MCP。

## 2. 事实源
- 架构 SSOT: [docs/02_架构与联调/05_EMAS_Serverless双环境迁移方案.md](../../../../docs/02_架构与联调/05_EMAS_Serverless双环境迁移方案.md)
- 接口 SSOT: [docs/03_接口与数据契约/01_API契约_v1_统一版.md](../../../../docs/03_接口与数据契约/01_API契约_v1_统一版.md)
- 官方参考: [references/official-sources.md](references/official-sources.md)
- RAM 授权样板: [references/stg-ram-policy.json](references/stg-ram-policy.json)
- 探测脚本: [scripts/emas_openapi.sh](scripts/emas_openapi.sh)

## 3. 默认技术路线
1. **控制面**：官方 Node SDK `@alicloud/mpserverless20190615`
2. **控制面辅助**：`aliyun` CLI 仅用于本机 profile 与 `sts GetCallerIdentity`
3. **控制面替代**：`aliyun mcp-proxy` 代理 OpenAPI MCP
4. **运行时**：`@alicloud/mpserverless-node-sdk`

当前已确认的控制面要点：
- OpenAPI 产品码：`mpserverless`
- OpenAPI 版本：`2019-06-15`
- 控制面 endpoint：`mpserverless.aliyuncs.com`
- `mpserverless.cn-hangzhou.aliyuncs.com` 当前在本机环境会 TLS 握手失败，不作为默认入口
- 当前 `aliyun` CLI `3.2.9` 未内置 `mpserverless` 产品命令，不能直接 `aliyun mpserverless ...`

## 4. 当前仓库的默认参数
- 默认 region：`cn-hangzhou`
- 默认 CLI profile：`bianlunmiao-emas`
- 默认控制面 endpoint：`mpserverless.aliyuncs.com`
- 调用入口脚本：`bash .agent/skills/aliyun-emas-serverless-ops/scripts/emas_openapi.sh`
- 当前 `stg` space：
  - `spaceName = bianlunmiao-stg`
  - `spaceId = mp-f66871d8-f47d-4051-a793-86c41f920aa1`
  - runtime endpoint = `https://fc-mp-f66871d8-f47d-4051-a793-86c41f920aa1.next.bspapp.com`
- 当前 `prod` space：
  - `spaceName = bianlunmiao_prod`
  - `spaceId = mp-ac3c9a37-fb9e-4486-9496-73fe4c034bd3`
  - 默认域名 = `https://fc-mp-ac3c9a37-fb9e-4486-9496-73fe4c034bd3.next.bspapp.com`
  - 自定义域名 CNAME = `fc-mp-ac3c9a37-fb9e-4486-9496-73fe4c034bd3-custom.next.bspapp.com`

## 5. 凭证规范
1. 优先使用 `aliyun` CLI profile，不把 AK、STS、`serverSecret` 写入仓库。
2. 若用户提供临时凭证，先写入本机 CLI profile，再执行控制面操作。
3. 若用户提供 `serverSecret`、`privateKey` 或 `apiKey`，只允许本地临时使用，不落盘到仓库文件。
4. 未经用户明确许可，不要重置 `serverSecret`、删除函数、删除集合或覆盖生产资源。
5. 若当前 shell 已注入临时凭证，可通过 `ALIYUN_PROFILE=''` 强制脚本不使用 profile。
6. RAM 用户至少需要 `mpserverless:DescribeSpaces`、`DescribeSpaceClientConfig`、函数部署、触发器、CORS 与 `RunDBCommand` 对应权限，否则控制面自动化会被 `403 NoPermission` 阻断。
7. 若要排查 `prod` 迁移中的数据库/存储初始化问题，额外需要 `mpserverless:DescribeServicePolicy`、`mpserverless:UpdateServicePolicy` 与 `mpserverless:ListFunctionLog`；缺这些权限时，无法自动对比 `stg/prod` 的服务策略，也无法读取线上函数报错日志。
7. 当前最小可用授权样板已落在 [references/stg-ram-policy.json](references/stg-ram-policy.json)，默认按 `stg` 迁移所需动作给到 `Resource: "*"` 先打通。

## 6. 默认工作流
1. 先跑：
   - `bash .agent/skills/aliyun-emas-serverless-ops/scripts/emas_openapi.sh check`
2. 再列 space：
   - `bash .agent/skills/aliyun-emas-serverless-ops/scripts/emas_openapi.sh call DescribeSpaces --json '{"pageNum":0,"pageSize":20}'`
3. 获取空间配置与 `serverSecret`：
   - `bash .agent/skills/aliyun-emas-serverless-ops/scripts/emas_openapi.sh call DescribeSpaceClientConfig --SpaceId <space_id>`
4. 管函数时优先用：
   - `CreateFunction`
   - `UpdateFunction`
   - `CreateFunctionDeployment`
   - `DeployFunction`
   - 当前函数 runtime 值应使用 `nodejs20`，不要传控制台展示文案 `Node.js 20`
   - `pnpm build:emas` 会重建 `.emas-build/`，同一工作区内不要并行跑多个环境打包
5. 管 HTTP 触发时优先用：
   - `DescribeHttpTriggerConfig`
   - `UpdateHttpTriggerConfig`
6. 管跨域时优先用：
   - `AddCorsDomain`
   - `DeleteCorsDomain`
7. 管云数据库时优先用：
   - `RunDBCommand`
8. 运行时接入 Node SDK 前，必须先拿到：
   - `spaceId`
   - runtime `endpoint`
   - `serverSecret`

当前仓库已验证的真实状态：
- profile `bianlunmiao-emas` 的 AK/SK 可用，`sts GetCallerIdentity` 正常
- 控制面 SDK 能成功打到 `mpserverless.aliyuncs.com`
- 当前 RAM 用户已可执行 `DescribeSpaces`、`DescribeSpaceClientConfig`、`DescribeHttpTriggerConfig` 与 `RunDBCommand`
- `DescribeSpaceClientConfig` 可返回 runtime `endpoint`、`apiKey`、`privateKey` 与文件上传 endpoint；脚本输出必须脱敏这些字段
- 若新建 `prod` space 的 `DescribeSpaceClientConfig` 返回缺失 `fileUploadEndpoint`，同时 `RunDBCommand` 在任意集合上报 `mongo_cell_decision_not_found`，优先判断为空间侧数据库/存储服务策略或初始化未完成，而不是业务代码本身异常
- `OpenService` 的有效 `ServiceName` 当前已确认至少包含 `CLOUD_FUNCTION`、`CLOUD_STORAGE`、`WEB_HOSTING`；为 `prod` 打开 `CLOUD_STORAGE` 后，`DescribeSpaceClientConfig` 会补出 `fileUploadEndpoint`
- `CreateFunctionDeployment` 与 `DeployFunction` 控制面接口可调用，但当前仓库从外部环境直传 `uploadSignedUrl` 仍返回 `SignatureDoesNotMatch`；函数代码上传暂时保留控制台“上传 js 包”作为兜底
- `CreateFunction` + `UpdateFunction` 已可成功用于 `prod` 自动创建 `api` / `healthz` 及其 `/api`、`/healthz` 路径；HTTP 总开关可通过 `UpdateHttpTriggerConfig(enableService=true)` 自动开启
- 当前 EMAS 控制台未提供函数环境变量配置入口；`stg` 所需 runtime 参数通过 `pnpm build:emas` 在打包阶段自动注入 zip，而不是在控制台单独配置
- `@alicloud/mpserverless-node-sdk` 需要在构建期以静态导入方式打入 bundle；当前仓库额外固定了 `proxy-agent@5`，否则 esbuild 会因 `urllib` 的动态 `require('proxy-agent')` 构建失败
- `RunDBCommand` / `RunFunction` 的 `Body` 参数必须是字符串；skill 脚本已内置兼容，`--body '{"collection":"users",...}'` 会按原样透传，不再被自动 JSON 解析破坏
- 当前已验证的 `RunDBCommand` 命令体格式可直接复用运行时 QueryService 产物：
  - `find`: `{"collection":"admin_users","query":{"email":"admin@bianlunmiao.top"},"options":{"limit":1},"command":"find"}`
  - `insertOne`: `{"collection":"admin_users","doc":{...},"options":{},"command":"insertOne"}`
  - `insertMany`: `{"collection":"users","docs":[...],"options":{},"command":"insertMany"}`
  - `deleteMany`: `{"collection":"users","filter":{"publicId":"codex-prod-probe"},"command":"deleteMany"}`
- `CreateDBImportTask` 当前已确认可接受 `Collection`、`FileType=JSON`、`Mode=UPSERT` 并返回 OSS 表单上传凭证；但在当前账号环境下，同样的最小 JSON 导入在 `stg/prod` 都会落到 `QueryDBImportTaskStatus=FAILED` 且 `detailMessage=INTERNAL_ERROR`，暂时不能用作集合初始化兜底
- 官方文档《创建数据表》明确给出了控制台建表路径，但这不是唯一已验证路径：`stg` 空间里，运行时 `insertOne` 到新集合可直接成功，说明 EMAS 在部分空间具备自动建集合能力
- 当前仓库已实测差异：
  - `stg`: `client.db.collection(<new>).insertOne(...) -> success`
  - `prod`: 同样操作返回 `mongo_cell_decision_not_found`
- 已定位 `prod` 的直接根因：集合缺少 `db` 权限策略（decision cell），而不是产品不支持自动建集合；对 `prod` 集合先执行 `UpdateServicePolicy(ServiceName=db, CollectionName=<name>, PolicyName=ADMINREADWRITEONLY)` 后，运行时 `insertOne/insertMany/find` 可立即恢复正常
- 当前仓库已内置 `pnpm --dir 辩论喵-后端-serverless ensure:db:policies:prod` 与 `ensure:db:policies:stg`，用于通过控制面批量补齐所有业务集合的 `db` 权限策略；这是 `prod` 数据库初始化的默认自动化入口
- 因此，若新空间默认域名 `healthz` 正常、函数日志显示请求已进入函数，但所有集合的 `find/insertOne` 都报 `mongo_cell_decision_not_found`，应优先执行 `ensure:db:policies:<env>`，而不是先回退到手工建表
- 当前 `prod` 默认域名 rehearsal 已实测通过：
  - `GET /healthz -> 200`
  - `POST /api admin.auth.login -> 200`
  - `POST /api admin.overview.get -> 200`
  - `POST /api auth.debug_token -> 403 DEBUG_TOKEN_DISABLED`
  - `POST /api users.me.get -> 200`
  - `POST /api media.avatar_upload_token -> 200`
- `DeleteDBCollection` 的请求参数当前已确认是 `Body + SpaceId`，其中 `Body` 至少需要 `{"collection":"<name>"}`；但当前 RAM 用户还缺 `mpserverless:DeleteDBCollection`，未授权前不要把探针集合清理写成默认自动化步骤

## 7. 什么时候读额外资料
- 需要官方依据、接口名或产品边界时：读 [references/official-sources.md](references/official-sources.md)
- 需要探测本机控制面调用时：用 [scripts/emas_openapi.sh](scripts/emas_openapi.sh)
- 需要看脚本实现细节时：读 [scripts/emas_control_plane.cjs](scripts/emas_control_plane.cjs)

## 8. 输出要求
- 每次执行 EMAS 自动化操作时，结果里至少说明：
  - 凭证模式：profile / STS / serverSecret
  - 控制面 endpoint
  - 调用的 OpenAPI 名称
  - 目标环境：`stg` 还是 `prod`
  - 是否改动了远端资源
  - 回滚入口或恢复方式

## 变更日志
- 2026-03-21: 新增 `RunDBCommand` 已验证命令体模板，并回写 `prod` 默认域名 rehearsal 通过结果；同时记录 `DeleteDBCollection` 还需要单独的 RAM 权限。
- 2026-03-21: 修正 `prod` 数据库初始化结论：`mongo_cell_decision_not_found` 的直接根因是集合缺少 `db` 权限策略（decision cell），不是产品不支持自动建集合；新增 `ensure:db:policies:{stg,prod}` 作为默认自动化修复入口。
- 2026-03-21: 修正集合初始化结论：`stg` 已实测可通过运行时 `insertOne` 自动创建新集合；`prod` 当前仍报 `mongo_cell_decision_not_found`，说明问题更像空间级能力差异而非产品不支持自动建表。
- 2026-03-21: 新增 `prod` 排障结论：`CLOUD_STORAGE` 可通过 `OpenService(ServiceName=CLOUD_STORAGE)` 自动开通并恢复 `fileUploadEndpoint`；同时记录 `CreateDBImportTask(Collection+JSON+UPSERT)` 的有效参数与当前 `INTERNAL_ERROR` 限制。
- 2026-03-21: 新增 `prod` 迁移排障结论：若默认域名 `healthz` 正常但 `/api` 全量 `500`，且 `DescribeSpaceClientConfig` 缺失 `fileUploadEndpoint`、`RunDBCommand` 返回 `mongo_cell_decision_not_found`，应优先补 `DescribeServicePolicy/UpdateServicePolicy/ListFunctionLog` 权限并检查空间侧数据库/存储初始化。
- 2026-03-20: 新增 `prod` space 的默认域名/CNAME，固定 `CreateFunction/UpdateFunction` 的 runtime 值为 `nodejs20`，并回写 `api/healthz` + 路径配置已可通过控制面自动创建。
- 2026-03-20: 修正控制面脚本对 `RunDBCommand` / `RunFunction` 的 `Body` 处理，避免 `--body` 被自动解析成对象后触发 `MissingBody` 或 `InvalidBody`。
- 2026-03-20: 修正 `stg` 部署方式，明确 runtime 参数通过 `build:emas` 构建期注入 zip，不再要求在 EMAS 控制台维护函数环境变量；同时记录 `proxy-agent@5` 是打包 Node SDK 的必要依赖。
- 2026-03-20: 新增控制面实测结论：`CreateFunctionDeployment` 可返回 `uploadSignedUrl`，但当前外部环境直传仍命中 `SignatureDoesNotMatch`，函数代码上传需保留控制台兜底。
- 2026-03-20: 新增 `apiKey/privateKey` 脱敏要求，并回写当前 `stg` RAM 授权已打通 `DescribeSpaces`、`DescribeSpaceClientConfig`、`DescribeHttpTriggerConfig` 与 `RunDBCommand`。
- 2026-03-20: 新增 `stg-ram-policy.json` 作为最小可用的 MPServerless RAM 授权样板。
- 2026-03-20: 将控制面主入口从错误的 `aliyun CLI + mpserverless 产品命令` 修正为官方 Node SDK `@alicloud/mpserverless20190615`，并固定 endpoint 为 `mpserverless.aliyuncs.com`。
- 2026-03-20: 初始化 EMAS Serverless 自动化操作 skill，收口 OpenAPI、CLI、MCP 与 Node SDK 的后续使用规范。

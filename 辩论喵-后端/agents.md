# agents.md

[PROTOCOL]: 变更时更新此头部，然后检查 agents.md

**版本**: v1.9
**日期**: 2026-03-23
**适用范围**: `/Users/Icarus/Documents/project 2026/bianlunmiao/辩论喵-后端`

## 1. 模块职责
1. 承载辩论喵后端 API、鉴权、数据模型、迁移与测试实现，现行同时承载 Web 管理后台 `admin.*` RPC、关系型管理写链路与审计。
2. 仅维护后端端内文档与实现细节；跨端契约以根目录 `docs/` 为 SSOT。

## 2. 目录结构
```text
./辩论喵-后端
├── agents.md
├── .dockerignore
├── .env.example
├── .gitignore
├── README.md
├── app/
├── alembic/
├── alembic.ini
├── scripts/
├── tests/
├── Dockerfile
├── docker-compose.yml
├── uv.lock
├── pyproject.toml
└── Makefile
```

## 3. 开发约束
1. 任何 API 字段、错误码语义变化，先更新根目录 `docs/03_接口与数据契约/` 再改实现。
2. 数据库结构变更必须同步 Alembic 迁移与测试用例。
3. 代码改动需通过 `make lint` 与 `make test`。

## 4. 质量门禁
1. `make lint`
2. `make test`

## 变更日志
- 2026-03-23: `team_members` 新增队内称呼字段与 Alembic 迁移，队伍成员写链路补充队内称呼更新接口。
- 2026-03-23: 媒体上传 token 新增显式 `PUBLIC_BASE_URL` 与代理头兜底，保证正式客户端获取到 `https` 的本地媒体地址，避免 iOS `ATS` 拦截。
- 2026-03-22: 新增 FC 启动期管理员幂等重置 hook，允许通过临时环境变量在正式环境安全重置后台管理员账号后再撤销开关。
- 2026-03-22: 手机号验证码链路改为服务端生成并持久化验证码摘要、本地完成核验；阿里云号码认证仅负责短信下发，数据库迁移新增 `sms_verification_codes.code_digest`。
- 2026-03-22: 后台 admin 能力扩展到入队申请审批、队伍成员管理、赛事参赛队伍管理、场次名单/赛果/状态推进，并补齐对应 RPC 与测试。
- 2026-03-22: 恢复 Web 管理后台现行 `admin.*` RPC、`admin_*` 数据模型与场次 CRUD，种子脚本补齐本地管理员 bootstrap。
- 2026-03-22: 后端正式入口收口为 `GET /healthz` 与 `POST /api`，本地媒体链路新增 `local/oss` 双后端与 `/uploads/*` 回环，作为 FC 单正式环境基线。
- 2026-03-20: 修正单仓根路径，并补齐 `.dockerignore`、`.env.example`、`.gitignore`、`alembic.ini` 与 `uv.lock` 目录索引。
- 2026-03-10: 补充账号注销后重新注册新账号的后端热修约束；实现需同步更新根目录接口契约与端内测试。
- 2026-03-05: 初始化后端 L2 协作文档，补齐分形文档系统层级约束。

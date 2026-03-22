# docs/03_接口与数据契约/agents.md - 接口数据契约索引

[PROTOCOL]: 变更时更新此头部，然后检查 agents.md

**版本**: v2.0
**日期**: 2026-03-22

## 目录结构
```text
./docs/03_接口与数据契约
├── agents.md
├── 01_API契约_v1_统一版.md
├── 02_数据库模型与迁移计划_v1.md
└── 03_错误码与响应规范.md
```

## 文件职责
- `01_API契约_v1_统一版.md`: 多端统一 API 契约，定义 `GET /healthz`、`POST /api` 与 `action` 命名空间。
- `02_数据库模型与迁移计划_v1.md`: 数据模型与迁移策略，覆盖 App 业务表、RDS PostgreSQL Serverless 目标态与测试账号命名规范。
- `03_错误码与响应规范.md`: 错误码、响应体与时间格式统一规则。

## 变更日志
- 2026-03-22: 接口契约模块切换为 `FC 单正式环境 + 本地开发` 基线，统一 `GET /healthz`、`POST /api` 与 App 业务动作。
- 2026-03-22: 数据模型目标更新为新购杭州 `RDS PostgreSQL Serverless`，Web 管理后台与 `admin_*` 现行模型退出现行范围。
- 2026-03-19: 新增 Web 管理后台 `admin` 契约、管理员数据模型与鉴权错误码约束。
- 2026-03-19: 为 `POST /auth/apple` 增补失败契约，明确非法 `identity_token/sub` 与 `sub` 越界统一返回 `401 APPLE_TOKEN_INVALID`。
- 2026-03-14: `01_API契约_v1_统一版.md` 补充赛事列表/详情/场次读取权限，统一为“创建者或参与者可见”。
- 2026-03-10: 调整账号注销后的 Apple 重新登录契约，补充“释放 `apple_sub` 后重新注册新账号”的语义，并同步数据库约束说明。
- 2026-03-06: 新增账号删除契约，补充 `DELETE /account`、`ACCOUNT_DELETED` 与 `users.deleted_at` 约束。
- 2026-03-04: `01_API契约_v1_统一版.md` 增补 `POST /auth/apple` 的 `isNewUser` 返回字段，支持客户端登录后新用户分流。
- 2026-02-17: 建立跨端接口与数据契约模块。

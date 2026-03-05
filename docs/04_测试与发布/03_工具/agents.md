# docs/04_测试与发布/03_工具/agents.md - 测试发布工具索引

[PROTOCOL]: 变更时更新此头部，然后检查 agents.md

**版本**: v1.2
**日期**: 2026-03-05

## 目录结构
```text
./docs/04_测试与发布/03_工具
├── agents.md
├── aliyun_cost_audit.py
└── stg_env_switch.py
```

## 文件职责
- `aliyun_cost_audit.py`: 使用阿里云 CLI 拉取辩论喵当前资源与成本，输出 Markdown 或 JSON。
- `stg_env_switch.py`: 一键执行 stg 环境 `on/off/status`，并进行最小化自验收。

## 局部约束
- 默认口径仅覆盖辩论喵项目资源，不做全账号泛审计。
- 对外输出结构保持稳定字段：`service`、`resource_id`、`env`、`billing_model`、`daily_cost`、`purpose`、`can_save`、`recommended_action`。
- 云资源拓扑变化后，必须同步回写 `docs/04_测试与发布` 文档索引和对应手册。

## 变更日志
- 2026-03-05: 工具目录从 `tools/` 迁移到 `03_工具/`，与测试发布分层结构保持一致。
- 2026-03-04: 新增阿里云资源与成本审计脚本索引。
- 2026-03-05: 新增 stg 环境按需启停脚本索引。

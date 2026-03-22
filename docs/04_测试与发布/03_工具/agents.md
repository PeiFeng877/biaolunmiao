# docs/04_测试与发布/03_工具/agents.md - 测试发布工具索引

[PROTOCOL]: 变更时更新此头部，然后检查 agents.md

**版本**: v1.4
**日期**: 2026-03-22

## 目录结构
```text
./docs/04_测试与发布/03_工具
├── agents.md
├── aliyun_cost_audit.py
└── stg_env_switch.py
```

## 文件职责
- `aliyun_cost_audit.py`: 使用阿里云 CLI 拉取辩论喵当前资源与成本，输出 Markdown 或 JSON。
- `stg_env_switch.py`: 历史资源退役探针，仅保留“旧 stg 已删除”的状态核对，不再作为现行 `on/off` 开关。

## 局部约束
- 默认口径仅覆盖辩论喵项目资源，不做全账号泛审计。
- 对外输出结构保持稳定字段：`service`、`resource_id`、`env`、`billing_model`、`daily_cost`、`purpose`、`can_save`、`recommended_action`。
- 云资源拓扑变化后，必须同步回写 `docs/04_测试与发布` 文档索引和对应手册。

## 变更日志
- 2026-03-22: `stg_env_switch.py` 收口为历史探针，现行测试发布口径切换为 FC 默认域名与正式后端复用。
- 2026-03-22: 明确 `stg_env_switch.py` 只用于确认遗留资源已删除，不再尝试唤起旧 stg。
- 2026-03-05: 工具目录从 `tools/` 迁移到 `03_工具/`，与测试发布分层结构保持一致。
- 2026-03-04: 新增阿里云资源与成本审计脚本索引。
- 2026-03-05: 新增 stg 环境按需启停脚本索引。

# docs/04_测试与发布/03_工具/agents.md - 测试发布工具索引

[PROTOCOL]: 变更时更新此头部，然后检查 agents.md

**版本**: v1.6
**日期**: 2026-03-22

## 目录结构
```text
./docs/04_测试与发布/03_工具
├── agents.md
└── aliyun_cost_audit.py
```

## 文件职责
- `aliyun_cost_audit.py`: 使用阿里云 CLI 拉取辩论喵当前资源与成本，输出 Markdown 或 JSON。

## 局部约束
- 默认口径仅覆盖辩论喵项目资源，不做全账号泛审计。
- 对外输出结构保持稳定字段：`service`、`resource_id`、`env`、`billing_model`、`daily_cost`、`purpose`、`can_save`、`recommended_action`。
- 云资源拓扑变化后，必须同步回写 `docs/04_测试与发布` 文档索引和对应手册。

## 变更日志
- 2026-03-22: 将 `stg_env_switch.py` 迁入 `docs/05_历史归档/05_阿里云阶段资料/`，现行工具目录只保留 FC 主路径仍在使用的审计脚本。
- 2026-03-22: `aliyun_cost_audit.py` 不再依赖本地 EMAS skill 脚本，避免历史技能退出主路径后出现悬挂引用。
- 2026-03-05: 工具目录从 `tools/` 迁移到 `03_工具/`，与测试发布分层结构保持一致。
- 2026-03-04: 新增阿里云资源与成本审计脚本索引。

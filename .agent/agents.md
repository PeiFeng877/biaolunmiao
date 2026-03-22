# .agent/agents.md - 仓库本地 Agent 配置索引

[PROTOCOL]: 变更时更新此头部，然后检查 agents.md

**版本**: v1.4
**日期**: 2026-03-22
**适用范围**: `/Users/Icarus/Documents/project 2026/bianlunmiao/.agent`

## 1. 模块职责
1. 承载仅对当前主仓生效的 Agent 本地配置、技能与工作流。
2. 这里的规则只服务辩论喵单仓，不扩散到全局 `CODEX_HOME`。

## 2. 目录结构
```text
./.agent
├── agents.md
└── skills/
    ├── agents.md
    ├── aliyun-fc-fastapi-ops/
    │   └── SKILL.md
    └── git-monorepo-guard/
        └── SKILL.md
```

## 3. 开发约束
1. 新增或修改本地 skill 时，必须同步更新本目录与 `skills/` 层级索引。
2. skill 内容应引用当前仓库现行 SSOT，不得复制一份平行规范。
3. 仓库本地 skill 仅描述当前仓库特有约束；通用知识不应堆入此目录。

## 变更日志
- 2026-03-22: 将本地后端操作 skill 切换为 `aliyun-fc-fastapi-ops/`，收口当前 `FC + FastAPI + RDS Serverless` 的现行操作路径。
- 2026-03-22: 旧 `aliyun-emas-serverless-ops/` 退出主仓现行技能目录，只保留本机忽略归档副本。
- 2026-03-20: 要求仓库本地 skill 说明统一使用中文，并补充推送排障与本地产物兜底约束。
- 2026-03-20: 初始化仓库本地 Agent 配置目录，新增单仓 Git 治理 skill 索引。

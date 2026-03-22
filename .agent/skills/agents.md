# .agent/skills/agents.md - 仓库本地技能索引

[PROTOCOL]: 变更时更新此头部，然后检查 agents.md

**版本**: v1.4
**日期**: 2026-03-22
**适用范围**: `/Users/Icarus/Documents/project 2026/bianlunmiao/.agent/skills`

## 1. 模块职责
1. 维护只作用于辩论喵单仓的本地技能。
2. 技能内容以“如何在这个仓库里做事”为核心，而不是通用工具说明。

## 2. 目录结构
```text
./.agent/skills
├── agents.md
├── aliyun-fc-fastapi-ops/
│   └── SKILL.md
└── git-monorepo-guard/
    └── SKILL.md
```

## 3. 技能说明
1. `git-monorepo-guard/`: 约束当前单仓的 Git 根、提交边界、推送前排障顺序、本地产物忽略规则与常见禁忌。
2. `aliyun-fc-fastapi-ops/`: 收口当前仓库对阿里云 FC、FastAPI、RDS PostgreSQL Serverless、OSS 与正式默认域名的现行操作规范。

## 变更日志
- 2026-03-22: 新增 `aliyun-fc-fastapi-ops`，统一当前 `FC + FastAPI + 新 RDS` 的操作入口与输出要求。
- 2026-03-22: 旧 `aliyun-emas-serverless-ops` 降级为本机忽略归档副本，不再保留在现行技能索引。
- 2026-03-20: 将 `git-monorepo-guard` 改写为中文说明，并补充推送失败排查与构建缓存防污染规则。
- 2026-03-20: 初始化本地技能索引，新增 `git-monorepo-guard`。

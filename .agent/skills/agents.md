# .agent/skills/agents.md - 仓库本地技能索引

[PROTOCOL]: 变更时更新此头部，然后检查 agents.md

**版本**: v1.3
**日期**: 2026-03-20
**适用范围**: `/Users/Icarus/Documents/project 2026/bianlunmiao/.agent/skills`

## 1. 模块职责
1. 维护只作用于辩论喵单仓的本地技能。
2. 技能内容以“如何在这个仓库里做事”为核心，而不是通用工具说明。

## 2. 目录结构
```text
./.agent/skills
├── agents.md
├── aliyun-emas-serverless-ops/
│   ├── .gitignore
│   ├── SKILL.md
│   ├── package.json
│   ├── pnpm-lock.yaml
│   ├── references/
│   │   ├── official-sources.md
│   │   └── stg-ram-policy.json
│   └── scripts/
│       ├── emas_control_plane.cjs
│       └── emas_openapi.sh
└── git-monorepo-guard/
    └── SKILL.md
```

## 3. 技能说明
1. `git-monorepo-guard/`: 约束当前单仓的 Git 根、提交边界、推送前排障顺序、本地产物忽略规则与常见禁忌。
2. `aliyun-emas-serverless-ops/`: 收口当前仓库后续对 EMAS Serverless 的控制面 SDK、凭证、RAM 授权样板、MCP 与运行时 Node SDK 自动化操作规范。

## 变更日志
- 2026-03-20: 为 `aliyun-emas-serverless-ops` 新增 `stg-ram-policy.json`，收口 EMAS `stg` 自动化所需的最小 RAM 授权样板。
- 2026-03-20: 为 `aliyun-emas-serverless-ops` 新增官方控制面 Node SDK 脚本 `emas_control_plane.cjs`，并保留 `emas_openapi.sh` 作为稳定 wrapper 入口。
- 2026-03-20: 新增 `aliyun-emas-serverless-ops`，统一 EMAS Serverless 的自动化调用入口、凭证规范与官方资料索引。
- 2026-03-20: 将 `git-monorepo-guard` 改写为中文说明，并补充推送失败排查与构建缓存防污染规则。
- 2026-03-20: 初始化本地技能索引，新增 `git-monorepo-guard`。

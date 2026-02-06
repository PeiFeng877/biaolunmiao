# BianLunMiao/Views/Tournament/Components/AGENTS.md - 赛事组件索引

[PROTOCOL]: 变更时更新此头部，然后检查 AGENTS.md

**版本**: v1.0
**日期**: 2026-02-04

## 模块职责
- 定位: 赛事相关页面的可复用组件集合。
- 边界: 仅包含视图组件，不承载业务逻辑。

## 目录结构
```
./BianLunMiao/Views/Tournament/Components
├── AGENTS.md
├── TournamentDetailComponents.swift
├── TournamentListComponents.swift
└── TournamentSetupComponents.swift
```

## 文件职责
- `TournamentListComponents.swift`: 赛事首页的搜索、筛选、卡片等组件。
- `TournamentDetailComponents.swift`: 赛事详情页的头部、Tab、赛程与队伍组件。
- `TournamentSetupComponents.swift`: 赛程设定/发布流程的表单与进度组件。

## 变更日志
- 2026-02-04: 初始化赛事组件索引。
- 2026-02-04: 顶部栏组件迁移至设计系统。

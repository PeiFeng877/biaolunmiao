# BianLunMiao/Views/Tournament/AGENTS.md - 赛事页面索引

[PROTOCOL]: 变更时更新此头部，然后检查 AGENTS.md

**版本**: v1.0
**日期**: 2026-02-08

## 模块职责
- 定位: 赛事主流程页面聚合层（列表、详情、创建、编排）。
- 边界: 仅做视图组合，业务状态由 `ViewModels/Tournament` 提供。

## 目录结构
```
./BianLunMiao/Views/Tournament
├── AGENTS.md
├── Components
│   ├── AGENTS.md
│   ├── TournamentDetailComponents.swift
│   ├── TournamentListComponents.swift
│   └── TournamentSetupComponents.swift
├── Setup
│   ├── AGENTS.md
│   ├── MatchManagementView.swift
│   ├── RosterEditView.swift
│   ├── TournamentPublishView.swift
│   └── TournamentScheduleSetupView.swift
├── CreateTournamentView.swift
├── TournamentDetailView.swift
└── TournamentListView.swift
```

## 文件职责
- `CreateTournamentView.swift`: 赛事创建流程入口。
- `TournamentListView.swift`: 赛事列表主页。
- `TournamentDetailView.swift`: 赛事详情容器页面。
- `Setup/*`: 赛事编排与发布流程页面。
- `Components/*`: 赛事复用视图组件。

## 变更日志
- 2026-02-08: 初始化赛事页面索引并引入 `Setup` 子模块，降低单层目录复杂度。

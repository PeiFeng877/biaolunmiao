# BianLunMiao/Views/AGENTS.md - 视图模块索引

[PROTOCOL]: 变更时更新此头部，然后检查 AGENTS.md

**版本**: v1.1
**日期**: 2026-02-04

## 模块职责
- 定位: iOS 端所有页面与子视图的组合层。
- 边界: 只做 UI 组合，数据来源于 ViewModel 与 Store。

## 目录结构
```
./BianLunMiao/Views
├── AGENTS.md
├── Schedule
│   └── ScheduleView.swift
├── Team
│   ├── AGENTS.md
│   ├── CreateTeamSheet.swift
│   ├── JoinTeamSheet.swift
│   ├── MemberDetailView.swift
│   ├── TeamDetailView.swift
│   ├── TeamListView.swift
│   └── TeamRow.swift
└── Tournament
    ├── Components
    │   ├── TournamentDetailComponents.swift
    │   ├── TournamentListComponents.swift
    │   └── TournamentSetupComponents.swift
    ├── CreateTournamentView.swift
    ├── MatchManagementView.swift
    ├── RosterEditView.swift
    ├── TournamentDetailView.swift
    ├── TournamentListView.swift
    ├── TournamentPublishView.swift
    └── TournamentScheduleSetupView.swift
```

## 开发规范
- 视图中不可硬编码颜色与间距。
- 组件优先复用 `Design` 模块。

## 变更日志
- 2026-02-04: 规范化头部信息并更新索引。
- 2026-02-04: 增加赛事详情页索引。
- 2026-02-04: 拆分赛事页组件并补充详情页布局。
- 2026-02-04: 增加赛程设定与发布赛事视图索引。
- 2026-02-04: 增加队伍子模块索引与成员详情页。

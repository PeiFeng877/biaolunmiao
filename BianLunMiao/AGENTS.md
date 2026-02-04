# BianLunMiao/AGENTS.md - iOS 应用模块索引

[PROTOCOL]: 变更时更新此头部，然后检查 AGENTS.md

**版本**: v1.1
**日期**: 2026-02-04

## 模块职责
- 定位: iOS 端主模块，承载 UI、数据模型、视图模型与应用入口。
- 边界: 仅包含客户端实现，不包含服务端代码。

## 目录结构
```
./BianLunMiao
├── AGENTS.md
├── BianLunMiaoApp.swift
├── ContentView.swift
├── Data
│   ├── AGENTS.md
│   ├── AppStore.swift
│   └── MockData.swift
├── Design
│   ├── AGENTS.md
│   ├── Theme.swift
│   └── Components.swift
├── Models
│   ├── AGENTS.md
│   ├── Match.swift
│   ├── Roster.swift
│   ├── Team.swift
│   ├── Tournament.swift
│   └── User.swift
├── ViewModels
│   ├── AGENTS.md
│   ├── MatchManagementViewModel.swift
│   ├── ScheduleViewModel.swift
│   ├── TeamDetailViewModel.swift
│   ├── TeamListViewModel.swift
│   ├── TournamentDetailViewModel.swift
│   ├── TournamentListViewModel.swift
│   ├── TournamentPublishViewModel.swift
│   └── TournamentScheduleSetupViewModel.swift
└── Views
    ├── AGENTS.md
    ├── Schedule
    │   └── ScheduleView.swift
    ├── Team
    │   ├── CreateTeamSheet.swift
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

## 架构决策
- 视图层通过 `Design` 目录统一调用设计系统令牌与组件。
- 业务逻辑集中在 `ViewModels`，状态集中在 `Data/AppStore`。

## 开发规范
- 新增/删除/重命名文件必须同步更新本清单与子模块 `AGENTS.md`。
- 视图禁止直接硬编码颜色与间距，必须从 `Design` 引用。
- Model 层禁止依赖 SwiftUI。

## 变更日志
- 2026-02-04: 补齐 Data/Models/ViewModels 索引并规范头部信息。
- 2026-02-04: 增加赛事详情视图与视图模型索引。
- 2026-02-04: 拆分赛事页组件并补充详情页布局。
- 2026-02-04: 增加赛事发布与赛程设定模块索引。

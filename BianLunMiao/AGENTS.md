# BianLunMiao/AGENTS.md - iOS 应用模块索引

[PROTOCOL]: 变更时更新此头部，然后检查 AGENTS.md

**版本**: v1.5
**日期**: 2026-02-08

## 模块职责
- 定位: iOS 端主模块，承载 UI、数据模型、视图模型与应用入口。
- 边界: 仅包含客户端实现，不包含服务端代码。

## 目录结构
```
./BianLunMiao
├── AGENTS.md
├── BianLunMiaoApp.swift
├── Assets.xcassets
├── Data
│   ├── AGENTS.md
│   ├── AppStore.swift
│   └── MockData.swift
├── DesignSystem
│   ├── AGENTS.md
│   ├── README.md
│   ├── ComponentsActions.swift
│   ├── ComponentsCore.swift
│   ├── ComponentsForm.swift
│   └── Theme.swift
├── Models
│   ├── AGENTS.md
│   ├── Match.swift
│   ├── Roster.swift
│   ├── Team.swift
│   ├── TeamJoinRequest.swift
│   ├── Tournament.swift
│   └── User.swift
├── ViewModels
│   ├── AGENTS.md
│   ├── Message
│   │   ├── AGENTS.md
│   │   └── MessageInboxViewModel.swift
│   ├── Schedule
│   │   ├── AGENTS.md
│   │   └── ScheduleViewModel.swift
│   ├── Team
│   │   ├── AGENTS.md
│   │   ├── MemberDetailViewModel.swift
│   │   ├── TeamDetailViewModel.swift
│   │   └── TeamListViewModel.swift
│   └── Tournament
│       ├── AGENTS.md
│       ├── MatchManagementViewModel.swift
│       ├── TournamentDetailViewModel.swift
│       ├── TournamentListViewModel.swift
│       ├── TournamentPublishViewModel.swift
│       └── TournamentScheduleSetupViewModel.swift
└── Views
    ├── AGENTS.md
    ├── Message
    │   ├── AGENTS.md
    │   ├── JoinRequestMessageDetailView.swift
    │   └── MessageInboxView.swift
    ├── Preview
    │   ├── AGENTS.md
    │   └── ContentView.swift
    ├── Schedule
    │   ├── AGENTS.md
    │   └── ScheduleView.swift
    ├── Team
    │   ├── AGENTS.md
    │   ├── CreateTeamSheet.swift
    │   ├── JoinTeamSheet.swift
    │   ├── MemberDetailView.swift
    │   ├── TeamDetailView.swift
    │   ├── TeamListView.swift
    │   ├── TeamSearchView.swift
    │   └── TeamRow.swift
    └── Tournament
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

## 架构决策
- 视图层通过 `DesignSystem` 目录统一调用设计系统令牌与组件。
- 业务逻辑按领域拆分到 `ViewModels/Schedule|Team|Tournament`，状态集中在 `Data/AppStore`。
- 赛事编排流程页面统一沉淀到 `Views/Tournament/Setup`，降低目录层级噪音。

## 开发规范
- 新增/删除/重命名文件必须同步更新本清单与子模块 `AGENTS.md`。
- 视图禁止直接硬编码颜色与间距，必须从 `DesignSystem` 引用。
- Model 层禁止依赖 SwiftUI。

## 变更日志
- 2026-02-08: 新增 `Models/TeamJoinRequest.swift` 与 `Views|ViewModels/Message` 子模块，补齐申请审批消息闭环。
- 2026-02-08: `Views/Team` 新增 `TeamSearchView.swift`，补齐队伍搜索与申请入队流程页面。
- 2026-02-08: `ViewModels` 按领域拆分 `Schedule/Team/Tournament` 子模块，修复单层文件数超限问题。
- 2026-02-08: `Views/Tournament` 新增 `Setup` 子模块，收敛编排流程页面。
- 2026-02-08: `ContentView.swift` 迁移至 `Views/Preview`，降低顶层目录复杂度。
- 2026-02-07: 设计系统组件拆分为 `ComponentsCore/Form/Actions.swift`，降低单文件复杂度。
- 2026-02-07: 设计系统升级为 Neo-Brutal Neon v2.0（token 与组件风格重构）。
- 2026-02-07: 在 `DesignSystem` 新增 `README.md`，作为设计系统可读规范入口。
- 2026-02-07: 设计系统目录从 `Design` 重命名为 `DesignSystem`。

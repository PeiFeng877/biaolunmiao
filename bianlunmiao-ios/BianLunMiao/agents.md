# BianLunMiao/agents.md - iOS 应用模块索引

[PROTOCOL]: 变更时更新此头部，然后检查 agents.md

**版本**: v2.7
**日期**: 2026-03-22

## 模块职责
- 定位: iOS 端主模块，承载 UI、数据模型、视图模型与应用入口。
- 边界: 仅包含客户端实现，不包含服务端代码。

## 目录结构
```
./BianLunMiao
├── agents.md
├── BianLunMiaoApp.swift
├── Info-Debug.plist
├── Info-Release.plist
├── auth_cat_yarn_hero_apng.png
├── Assets.xcassets
├── Data
│   ├── agents.md
│   ├── AppStore+TeamHelpers.swift
│   ├── AppStore.swift
│   ├── MockData.swift
│   ├── RemoteGateway.swift
│   └── RuntimeOverrides.swift
├── DesignSystem
│   ├── agents.md
│   ├── README.md
│   ├── ComponentsActions.swift
│   ├── ComponentsButtonAPI.swift
│   ├── ComponentsCore.swift
│   ├── ComponentsFeedback.swift
│   ├── ComponentsForm.swift
│   └── Theme.swift
├── Models
│   ├── agents.md
│   ├── Match.swift
│   ├── Message
│   │   └── InboxMessage.swift
│   ├── Roster.swift
│   ├── ScheduleSource.swift
│   ├── Team.swift
│   ├── TeamJoinRequest.swift
│   ├── Tournament.swift
│   └── User.swift
├── ViewModels
│   ├── agents.md
│   ├── Message
│   │   ├── agents.md
│   │   └── MessageInboxViewModel.swift
│   ├── My
│   │   ├── agents.md
│   │   └── ProfileSettingsViewModel.swift
│   ├── Schedule
│   │   ├── agents.md
│   │   └── ScheduleViewModel.swift
│   ├── Team
│   │   ├── agents.md
│   │   ├── MemberDetailViewModel.swift
│   │   ├── TeamDetailViewModel.swift
│   │   └── TeamListViewModel.swift
│   └── Tournament
│       ├── agents.md
│       ├── MatchManagementViewModel.swift
│       ├── TournamentDetailViewModel.swift
│       ├── TournamentListViewModel.swift
│       ├── TournamentPublishViewModel.swift
│       └── TournamentScheduleSetupViewModel.swift
└── Views
    ├── agents.md
    ├── Message
    │   ├── agents.md
    │   ├── JoinRequestMessageDetailView.swift
    │   ├── MessageHubView.swift
    │   └── MessageInboxView.swift
    ├── My
    │   ├── agents.md
    │   ├── MyHubView.swift
    │   ├── ProfileMoreView.swift
    │   └── ProfileSettingsView.swift
    ├── Preview
    │   ├── agents.md
    │   └── ContentView.swift
    ├── Schedule
    │   ├── agents.md
    │   ├── Components
    │   │   ├── ScheduleBatchSyncSheet.swift
    │   │   └── ScheduleEventDetailComponents.swift
    │   ├── ScheduleSourceManagementView.swift
    │   ├── ScheduleSourcePickerSheet.swift
    │   ├── ScheduleView+CalendarSync.swift
    │   └── ScheduleView.swift
    ├── Team
    │   ├── agents.md
    │   ├── CreateTeamSheet.swift
    │   ├── JoinTeamSheet.swift
    │   ├── MemberDetailView.swift
    │   ├── TeamDetailView.swift
    │   ├── TeamListView.swift
    │   ├── TeamSearchView.swift
    │   └── TeamRow.swift
    └── Tournament
        ├── agents.md
        ├── Components
        │   ├── agents.md
        │   ├── TournamentDetailComponents.swift
        │   ├── TournamentListComponents.swift
        │   └── TournamentSetupComponents.swift
        ├── Setup
        │   ├── agents.md
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
- 业务逻辑按领域拆分到 `ViewModels` 子模块，状态集中在 `Data/AppStore`。
- 应用入口改为“鉴权门禁 -> 新用户资料完善 / 5 Tab 主容器”，启动阶段必须先恢复会话或进入 Apple 登录页。
- 应用主导航固定为 5 Tab：队伍/赛事/日程/消息/我的。
- 消息入口独立为 `Views/Message/MessageHubView.swift`，我的页仅承载资料与设置。
- 运行态只保留 `local/prod` 两态，正式路径预留 FC 默认域名基址，通过环境变量显式覆盖，禁止再把 `stg` 视为现行环境。

## 开发规范
- 新增/删除/重命名文件必须同步更新本清单与子模块 `agents.md`。
- 视图禁止直接硬编码颜色与间距，必须从 `DesignSystem` 引用。
- Model 层禁止依赖 SwiftUI。

## 变更日志
- 2026-03-22: Release 构建号收口到 `1.0.1 (102)`，正式包与 TestFlight 继续复用当前 FC 默认域名基址。
- 2026-03-19: `Data` 子模块新增 `RuntimeOverrides.swift`，统一承接 UI 自动化与 Maestro 的环境/启动参数覆盖。
- 2026-03-19: 新增 `Info-Debug.plist` 与 `Info-Release.plist`，收口 App Transport Security 与基础应用元数据；Debug 允许当前 HTTP staging，Release 保持正式 HTTPS 约束。
- 2026-03-22: 收口客户端运行态为 `local/prod` 两态，正式环境改为预留 FC 默认域名基址。
- 2026-03-04: Apple 登录成功后新增 `isNewUser` 分流；新用户进入资料完善页，完成头像与昵称设置后再进入队伍页。
- 2026-03-03: 新增 `auth_cat_yarn_hero_apng.png` 原始 APNG 资源；`BianLunMiaoApp` 登录门禁页改为播放 APNG hero，并使用独立鉴权背景色 token。
- 2026-03-02: `BianLunMiao.entitlements` 移出 App 同步目录，避免 Xcode 在构建期修改源 entitlements 文件。
- 2026-03-02: 新增 `BianLunMiao.entitlements`，为 Apple 登录补齐 `Sign in with Apple` capability 与签名声明。
- 2026-03-02: `BianLunMiaoApp` 改为鉴权门禁根视图，接入 Apple 登录入口并收口启动错误页。
- 2026-02-26: 同步目录同构，补充 `Data/RemoteGateway.swift`、`Models/Message`、`ScheduleSource.swift` 与 `Views/My|Schedule` 的最新文件结构。
- 2026-02-15: `BianLunMiaoApp` 调整为 5 Tab（队伍/赛事/日程/消息/我的），恢复消息独立 Tab。
- 2026-02-15: 新增 `Views/Message/MessageHubView.swift`，消息详情路由从 `MyHubView` 迁出。
- 2026-02-15: `ViewModels/Message/MessageInboxViewModel.swift` 改为统一 `feedItems` 扁平消息流。
- 2026-02-13: `BianLunMiaoApp` Tab 重组为队伍/赛事/日程/我的，消息并入我的页。
- 2026-02-13: 新增 `Models/InboxMessage.swift`、`Views/My` 与 `ViewModels/My` 子模块。
- 2026-02-08: 设计系统新增 `ComponentsButtonAPI.swift` 与 `ComponentsFeedback.swift`，统一业务层按钮与提示入口。
- 2026-02-08: 新增 `Models/TeamJoinRequest.swift` 与 `Views|ViewModels/Message` 子模块，补齐申请审批消息闭环。
- 2026-02-08: `Views/Team` 新增 `TeamSearchView.swift`，补齐队伍搜索与申请入队流程页面。
- 2026-02-08: `ViewModels` 按领域拆分 `Schedule/Team/Tournament` 子模块，修复单层文件数超限问题。
- 2026-02-08: `Views/Tournament` 新增 `Setup` 子模块，收敛编排流程页面。
- 2026-02-08: `ContentView.swift` 迁移至 `Views/Preview`，降低顶层目录复杂度。
- 2026-02-07: 设计系统组件拆分为 `ComponentsCore/Form/Actions.swift`，降低单文件复杂度。
- 2026-02-07: 设计系统升级为 Neo-Brutal Neon v2.0（token 与组件风格重构）。
- 2026-02-07: 在 `DesignSystem` 新增 `README.md`，作为设计系统可读规范入口。
- 2026-02-07: 设计系统目录从 `Design` 重命名为 `DesignSystem`。

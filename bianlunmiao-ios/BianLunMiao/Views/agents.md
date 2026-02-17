# BianLunMiao/Views/agents.md - 视图模块索引

[PROTOCOL]: 变更时更新此头部，然后检查 agents.md

**版本**: v1.7
**日期**: 2026-02-16

## 模块职责
- 定位: iOS 端所有页面与子视图的组合层。
- 边界: 只做 UI 组合，数据来源于 ViewModel 与 Store。

## 目录结构
```
./BianLunMiao/Views
├── agents.md
├── Message
│   ├── agents.md
│   ├── JoinRequestMessageDetailView.swift
│   ├── MessageHubView.swift
│   └── MessageInboxView.swift
├── My
│   ├── agents.md
│   ├── MyHubView.swift
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

## 开发规范
- 视图中不可硬编码颜色与间距。
- 组件优先复用 `DesignSystem` 模块。
- 页面按领域拆分子目录，单层目录文件数量控制在 8 以内。

## 变更日志
- 2026-02-16: `Schedule` 子模块拆分批量同步与日历同步扩展文件，主视图降至 800 行以内。
- 2026-02-15: `Message` 子模块新增 `MessageHubView.swift` 作为消息 Tab 根页面。
- 2026-02-15: `MyHubView` 从“消息/设置分段”简化为“我的设置”平铺根页。
- 2026-02-15: `MessageInboxView` 改为无分类的单流卡片消息展示。
- 2026-02-13: 新增 `My` 子模块，承载我的页（消息/设置）组合。
- 2026-02-13: `MessageInboxView` 从独立 Tab 根页调整为“我的页”内嵌内容。
- 2026-02-08: 新增 `Message` 子模块，承载入队申请消息收件箱与详情审批页面。
- 2026-02-08: `Team` 子模块新增 `TeamSearchView.swift`，承载队伍搜索与入队申请流程。
- 2026-02-08: 新增 `Preview/Schedule/Tournament` 子模块级 `agents.md`，补齐 L2 文档层。
- 2026-02-08: `Tournament` 下拆分 `Setup` 子目录，降低单层复杂度。
- 2026-02-08: `ContentView.swift` 迁移到 `Preview` 子目录。
- 2026-02-07: 设计系统目录重命名为 `DesignSystem` 并更新引用约束。

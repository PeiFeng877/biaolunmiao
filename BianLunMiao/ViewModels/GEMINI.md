# BianLunMiao/ViewModels/GEMINI.md - 视图模型索引

[PROTOCOL]: 变更时更新此头部，然后检查 GEMINI.md

**版本**: v1.3
**日期**: 2026-02-13

## 模块职责
- 定位: 将 AppStore 数据转为视图状态，承载业务操作。
- 边界: 不直接渲染 UI。

## 目录结构
```
./BianLunMiao/ViewModels
├── GEMINI.md
├── Message
│   ├── GEMINI.md
│   └── MessageInboxViewModel.swift
├── My
│   ├── GEMINI.md
│   └── ProfileSettingsViewModel.swift
├── Schedule
│   ├── GEMINI.md
│   └── ScheduleViewModel.swift
├── Team
│   ├── GEMINI.md
│   ├── MemberDetailViewModel.swift
│   ├── TeamDetailViewModel.swift
│   └── TeamListViewModel.swift
└── Tournament
    ├── GEMINI.md
    ├── MatchManagementViewModel.swift
    ├── TournamentDetailViewModel.swift
    ├── TournamentListViewModel.swift
    ├── TournamentPublishViewModel.swift
    └── TournamentScheduleSetupViewModel.swift
```

## 文件职责
- `Message/MessageInboxViewModel.swift`: 消息分段聚合与审批/确认动作转发。
- `My/ProfileSettingsViewModel.swift`: 我的设置页资料编辑与协议入口状态。
- `Schedule/ScheduleViewModel.swift`: 我的/关注赛程状态管理。
- `Team/*`: 队伍列表、队伍详情、成员详情状态管理。
- `Tournament/*`: 赛事列表、详情、排程、发布状态管理。

## 开发规范
- 仅与 AppStore/Models 交互，禁止在此直接写 UI 逻辑。
- 新增 ViewModel 时优先归入对应领域目录，避免根目录膨胀。

## 变更日志
- 2026-02-13: 新增 `My` 子模块，承载个人资料编辑设置状态。
- 2026-02-13: `Message` 增加通知/状态变更消息聚合与确认动作。
- 2026-02-08: 新增 `Message` 子模块，承载入队申请消息聚合与审批动作。
- 2026-02-08: 将根目录 ViewModel 按业务域拆分为 `Schedule/Team/Tournament`。
- 2026-02-04: 初始化视图模型索引。

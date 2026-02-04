# BianLunMiao/ViewModels/AGENTS.md - 视图模型索引

[PROTOCOL]: 变更时更新此头部，然后检查 AGENTS.md

**版本**: v1.0
**日期**: 2026-02-04

## 模块职责
- 定位: 将 AppStore 数据转为视图状态，承载业务操作。
- 边界: 不直接渲染 UI。

## 目录结构
```
./BianLunMiao/ViewModels
├── AGENTS.md
├── MatchManagementViewModel.swift
├── ScheduleViewModel.swift
├── TeamDetailViewModel.swift
├── TeamListViewModel.swift
├── TournamentDetailViewModel.swift
├── TournamentListViewModel.swift
├── TournamentPublishViewModel.swift
└── TournamentScheduleSetupViewModel.swift
```

## 文件职责
- `TeamListViewModel.swift`: 队伍列表状态与创建入口。
- `TeamDetailViewModel.swift`: 队伍详情与成员管理状态。
- `ScheduleViewModel.swift`: 个人赛程状态与刷新逻辑。
- `TournamentListViewModel.swift`: 赛事瀑布流卡片状态。
- `TournamentDetailViewModel.swift`: 赛事详情展示状态。
- `MatchManagementViewModel.swift`: 赛程管理与指派入口状态。
- `TournamentScheduleSetupViewModel.swift`: 赛程设定流程与轮次配置状态。
- `TournamentPublishViewModel.swift`: 发布赛事摘要与确认状态。

## 开发规范
- 仅与 AppStore/Models 交互，禁止在此直接写 UI 逻辑。

## 变更日志
- 2026-02-04: 初始化视图模型索引。
- 2026-02-04: 增加赛事详情视图模型索引。
- 2026-02-04: 增加赛程设定与发布赛事视图模型索引。

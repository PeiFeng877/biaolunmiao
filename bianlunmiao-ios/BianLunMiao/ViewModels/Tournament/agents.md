# BianLunMiao/ViewModels/Tournament/agents.md - 赛事视图模型索引

[PROTOCOL]: 变更时更新此头部，然后检查 agents.md

**版本**: v1.0
**日期**: 2026-02-08

## 模块职责
- 定位: 赛事主流程（列表、详情、编排、发布）状态管理。
- 边界: 仅处理赛事领域，不承载队伍页面逻辑。

## 目录结构
```
./BianLunMiao/ViewModels/Tournament
├── agents.md
├── MatchManagementViewModel.swift
├── TournamentDetailViewModel.swift
├── TournamentListViewModel.swift
├── TournamentPublishViewModel.swift
└── TournamentScheduleSetupViewModel.swift
```

## 文件职责
- `TournamentListViewModel.swift`: 赛事列表状态。
- `TournamentDetailViewModel.swift`: 赛事详情状态。
- `MatchManagementViewModel.swift`: 对阵与编排管理状态。
- `TournamentScheduleSetupViewModel.swift`: 赛程设定状态。
- `TournamentPublishViewModel.swift`: 发布确认状态。

## 变更日志
- 2026-02-08: 从 `ViewModels` 根目录拆分 `Tournament` 子模块，减少模块耦合。

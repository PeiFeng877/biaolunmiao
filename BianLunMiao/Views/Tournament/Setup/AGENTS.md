# BianLunMiao/Views/Tournament/Setup/AGENTS.md - 赛事编排流程索引

[PROTOCOL]: 变更时更新此头部，然后检查 AGENTS.md

**版本**: v1.0
**日期**: 2026-02-08

## 模块职责
- 定位: 赛事赛程设定、排兵布阵、发布确认流程页面集合。
- 边界: 不定义复用组件，仅编排流程页面。

## 目录结构
```
./BianLunMiao/Views/Tournament/Setup
├── AGENTS.md
├── MatchManagementView.swift
├── RosterEditView.swift
├── TournamentPublishView.swift
└── TournamentScheduleSetupView.swift
```

## 文件职责
- `TournamentScheduleSetupView.swift`: 赛程轮次、规则设定页面。
- `MatchManagementView.swift`: 对阵管理与指派页面。
- `RosterEditView.swift`: 上场名单编辑页面。
- `TournamentPublishView.swift`: 发布前确认页面。

## 变更日志
- 2026-02-08: 从 `Tournament` 根目录拆分 `Setup` 子模块，减少特殊分支与目录拥挤。

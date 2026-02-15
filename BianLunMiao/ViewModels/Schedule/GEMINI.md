# BianLunMiao/ViewModels/Schedule/GEMINI.md - 赛程视图模型索引

[PROTOCOL]: 变更时更新此头部，然后检查 GEMINI.md

**版本**: v1.2
**日期**: 2026-02-13

## 模块职责
- 定位: 管理日程页面状态机（月视图/日详情）与数据源聚合。
- 边界: 仅负责赛程领域状态转换。

## 目录结构
```
./BianLunMiao/ViewModels/Schedule
├── GEMINI.md
└── ScheduleViewModel.swift
```

## 文件职责
- `ScheduleViewModel.swift`: 月历锚点、日详情切换、数据源管理与赛事聚合状态。

## 变更日志
- 2026-02-13: 重构为 Apple 风格日程状态机，新增数据源管理与本地持久化。
- 2026-02-13: 增加“我的/关注”作用域状态和关注对象选择逻辑。
- 2026-02-08: 从 `ViewModels` 根目录拆分 `Schedule` 子模块。

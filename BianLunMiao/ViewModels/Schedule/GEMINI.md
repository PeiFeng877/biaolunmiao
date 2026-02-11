# BianLunMiao/ViewModels/Schedule/GEMINI.md - 赛程视图模型索引

[PROTOCOL]: 变更时更新此头部，然后检查 GEMINI.md

**版本**: v1.0
**日期**: 2026-02-08

## 模块职责
- 定位: 管理个人赛程页面的状态与交互动作。
- 边界: 仅负责赛程领域视图状态转换。

## 目录结构
```
./BianLunMiao/ViewModels/Schedule
├── GEMINI.md
└── ScheduleViewModel.swift
```

## 文件职责
- `ScheduleViewModel.swift`: 赛程列表、筛选与刷新状态管理。

## 变更日志
- 2026-02-08: 从 `ViewModels` 根目录拆分 `Schedule` 子模块。

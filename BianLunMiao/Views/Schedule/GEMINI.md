# BianLunMiao/Views/Schedule/GEMINI.md - 赛程页面索引

[PROTOCOL]: 变更时更新此头部，然后检查 GEMINI.md

**版本**: v1.2
**日期**: 2026-02-13

## 模块职责
- 定位: 日程页面组合层，承载 Apple 风格月历与当日详情流。
- 边界: 仅做赛程 UI 渲染，状态来自 `ScheduleViewModel`。

## 目录结构
```
./BianLunMiao/Views/Schedule
├── Components
│   └── ScheduleEventDetailComponents.swift
├── GEMINI.md
├── ScheduleSourceManagementView.swift
├── ScheduleSourcePickerSheet.swift
└── ScheduleView.swift
```

## 文件职责
- `ScheduleView.swift`: 月历主视图、周视图切换、详情区与浮动操作按钮。
- `ScheduleSourceManagementView.swift`: 数据源管理页（个人/队伍/赛事三类 Tab）。
- `ScheduleSourcePickerSheet.swift`: 数据源搜索添加弹窗（按 ID/名称检索）。
- `Components/ScheduleEventDetailComponents.swift`: 当日赛事详情卡与时间轴组件。

## 变更日志
- 2026-02-13: 升级为 Apple 风格交互，新增日历管理页、搜索弹窗与时间轴组件。
- 2026-02-13: 日程页升级为“我的/关注”双分段，关注支持队伍/队员两类对象。
- 2026-02-08: 初始化赛程页面索引，补齐 L2 分形文档。

# BianLunMiao/Views/Schedule/agents.md - 赛程页面索引

[PROTOCOL]: 变更时更新此头部，然后检查 agents.md

**版本**: v1.4
**日期**: 2026-03-23

## 模块职责
- 定位: 日程页面组合层，承载 Apple 风格月历与当日详情流。
- 边界: 仅做赛程 UI 渲染，状态来自 `ScheduleViewModel`。

## 目录结构
```
./BianLunMiao/Views/Schedule
├── Components
│   ├── ScheduleBatchSyncSheet.swift
│   └── ScheduleEventDetailComponents.swift
├── agents.md
├── ScheduleSourceManagementView.swift
├── ScheduleSourcePickerSheet.swift
├── ScheduleView+CalendarSync.swift
└── ScheduleView.swift
```

## 文件职责
- `ScheduleView.swift`: 月历主视图、周视图切换、详情区、浮动操作按钮与下拉刷新入口。
- `ScheduleView+CalendarSync.swift`: 系统日历同步、去重判定与提示反馈逻辑扩展。
- `ScheduleSourceManagementView.swift`: 数据源管理页（个人/队伍/赛事三类 Tab）。
- `ScheduleSourcePickerSheet.swift`: 数据源搜索添加弹窗（按 ID/名称检索）。
- `Components/ScheduleBatchSyncSheet.swift`: 批量同步弹层，负责多选与确认提交流程。
- `Components/ScheduleEventDetailComponents.swift`: 当日赛事详情卡与时间轴组件。

## 变更日志
- 2026-02-16: 拆分 `ScheduleBatchSyncSheet` 与 `ScheduleView+CalendarSync`，将 `ScheduleView.swift` 控制到 800 行内。
- 2026-03-23: 日程根页接入缓存优先后的下拉刷新入口，统一复用 `AppStore.refreshNow(force:)`。
- 2026-02-13: 升级为 Apple 风格交互，新增日历管理页、搜索弹窗与时间轴组件。
- 2026-02-13: 日程页升级为“我的/关注”双分段，关注支持队伍/队员两类对象。
- 2026-02-08: 初始化赛程页面索引，补齐 L2 分形文档。

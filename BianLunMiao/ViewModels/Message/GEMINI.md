# BianLunMiao/ViewModels/Message/GEMINI.md - 消息视图模型索引

[PROTOCOL]: 变更时更新此头部，然后检查 GEMINI.md

**版本**: v1.1
**日期**: 2026-02-13

## 模块职责
- 定位: 消息收件箱状态聚合（申请/通知/状态变更）与动作转发。
- 边界: 仅聚合 AppStore 状态，不承载 UI 结构。

## 目录结构
```
./BianLunMiao/ViewModels/Message
├── GEMINI.md
└── MessageInboxViewModel.swift
```

## 文件职责
- `MessageInboxViewModel.swift`: 构建三类消息分段，并提供审批与确认动作。

## 变更日志
- 2026-02-13: 新增通知/状态变更消息聚合与消息确认动作。
- 2026-02-08: 初始化消息视图模型子模块，承载入队申请消息聚合。

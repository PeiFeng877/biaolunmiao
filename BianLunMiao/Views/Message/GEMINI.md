# BianLunMiao/Views/Message/GEMINI.md - 消息页面索引

[PROTOCOL]: 变更时更新此头部，然后检查 GEMINI.md

**版本**: v1.1
**日期**: 2026-02-13

## 模块职责
- 定位: 消息页面组合层，展示申请、通知与状态变更消息。
- 边界: 仅组合 UI，不直接处理业务状态。

## 目录结构
```
./BianLunMiao/Views/Message
├── GEMINI.md
├── JoinRequestMessageDetailView.swift
└── MessageInboxView.swift
```

## 文件职责
- `MessageInboxView.swift`: 消息内容视图，分段展示待处理申请、通知与状态变更。
- `JoinRequestMessageDetailView.swift`: 入队申请消息详情页，提供审批操作。

## 变更日志
- 2026-02-13: `MessageInboxView` 升级为“我的页”内嵌内容，新增通知/状态变更分段与消息确认动作。
- 2026-02-08: 初始化消息页面子模块，接入入队申请审批与结果通知流程。

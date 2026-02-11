# BianLunMiao/Views/Message/GEMINI.md - 消息页面索引

[PROTOCOL]: 变更时更新此头部，然后检查 GEMINI.md

**版本**: v1.0
**日期**: 2026-02-08

## 模块职责
- 定位: 消息中心页面组合层，展示入队申请待处理与结果通知。
- 边界: 仅组合 UI，不直接处理业务状态。

## 目录结构
```
./BianLunMiao/Views/Message
├── GEMINI.md
├── JoinRequestMessageDetailView.swift
└── MessageInboxView.swift
```

## 文件职责
- `MessageInboxView.swift`: 消息 Tab 根页面，分区展示待处理申请和申请结果。
- `JoinRequestMessageDetailView.swift`: 消息详情页，提供审批操作与结果只读信息。

## 变更日志
- 2026-02-08: 初始化消息页面子模块，接入入队申请审批与结果通知流程。

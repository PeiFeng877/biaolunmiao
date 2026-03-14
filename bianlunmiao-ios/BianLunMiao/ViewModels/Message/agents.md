# BianLunMiao/ViewModels/Message/agents.md - 消息视图模型索引

[PROTOCOL]: 变更时更新此头部，然后检查 agents.md

**版本**: v1.2
**日期**: 2026-02-15

## 模块职责
- 定位: 消息收件箱状态聚合（统一单流）与审批动作转发。
- 边界: 仅聚合 AppStore 状态，不承载 UI 结构。

## 目录结构
```
./BianLunMiao/ViewModels/Message
├── agents.md
└── MessageInboxViewModel.swift
```

## 文件职责
- `MessageInboxViewModel.swift`: 构建统一 `feedItems` 倒序消息流，并提供审批动作。

## 变更日志
- 2026-02-15: 移除消息分段状态，新增 `MessageFeedItem` 与统一 `feedItems` 输出。
- 2026-02-13: 新增通知/状态变更消息聚合与消息确认动作。
- 2026-02-08: 初始化消息视图模型子模块，承载入队申请消息聚合。

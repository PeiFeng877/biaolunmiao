# BianLunMiao/Views/Message/GEMINI.md - 消息页面索引

[PROTOCOL]: 变更时更新此头部，然后检查 GEMINI.md

**版本**: v1.2
**日期**: 2026-02-15

## 模块职责
- 定位: 消息页面组合层，展示统一消息流并承接申请详情路由。
- 边界: 仅组合 UI，不直接处理业务状态。

## 目录结构
```
./BianLunMiao/Views/Message
├── GEMINI.md
├── JoinRequestMessageDetailView.swift
├── MessageHubView.swift
└── MessageInboxView.swift
```

## 文件职责
- `MessageHubView.swift`: 消息 Tab 根页面，承接收件箱与详情导航。
- `MessageInboxView.swift`: 消息内容视图，统一倒序卡片流展示。
- `JoinRequestMessageDetailView.swift`: 入队申请消息详情页，提供审批操作。

## 变更日志
- 2026-02-15: 新增 `MessageHubView`，恢复消息独立 Tab 路由。
- 2026-02-15: `MessageInboxView` 去除分段分类，改为扁平卡片信息流。
- 2026-02-13: `MessageInboxView` 升级为“我的页”内嵌内容，新增通知/状态变更分段与消息确认动作。
- 2026-02-08: 初始化消息页面子模块，接入入队申请审批与结果通知流程。

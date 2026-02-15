# BianLunMiao/Views/My/GEMINI.md - 我的页面索引

[PROTOCOL]: 变更时更新此头部，然后检查 GEMINI.md

**版本**: v1.0
**日期**: 2026-02-13

## 模块职责
- 定位: 我的 Tab 页面组合层，承载消息与设置双分段。
- 边界: 仅负责 UI 组合，不直接处理业务状态。

## 目录结构
```
./BianLunMiao/Views/My
├── GEMINI.md
├── MyHubView.swift
└── ProfileSettingsView.swift
```

## 文件职责
- `MyHubView.swift`: 我的 Tab 根页面，提供消息/设置分段与消息详情路由。
- `ProfileSettingsView.swift`: 个人资料、版本信息、协议与隐私入口页面。

## 变更日志
- 2026-02-13: 初始化我的页面子模块，承载消息并入与设置基础设施入口。

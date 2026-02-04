# BianLunMiao/Design/AGENTS.md - 设计系统模块

[PROTOCOL]: 变更时更新此头部，然后检查 AGENTS.md

**版本**: v1.1
**日期**: 2026-02-04

## 模块职责
- 定位: 统一承载颜色、字体、间距、组件样式等设计系统规范。
- 边界: 不包含业务逻辑，仅提供 UI 复用能力。

## 目录结构
```
./BianLunMiao/Design
├── AGENTS.md
├── Theme.swift
└── Components.swift
```

## 文件职责
- `Theme.swift`: 颜色、字体、间距、圆角、阴影等基础令牌。
- `Components.swift`: 卡片、按钮、标签、空状态等可复用组件。

## 变更日志
- 2026-02-04: 规范化头部信息并更新索引。

# BianLunMiao/Models/AGENTS.md - 模型层索引

[PROTOCOL]: 变更时更新此头部，然后检查 AGENTS.md

**版本**: v1.0
**日期**: 2026-02-04

## 模块职责
- 定位: 业务实体与枚举定义。
- 边界: 纯数据结构，无 UI、无网络。

## 目录结构
```
./BianLunMiao/Models
├── AGENTS.md
├── Match.swift
├── Roster.swift
├── Team.swift
├── Tournament.swift
└── User.swift
```

## 文件职责
- `User.swift`: 用户实体与状态枚举。
- `Team.swift`: 队伍、成员、角色与头像样式定义。
- `Tournament.swift`: 赛事实体与状态。
- `Match.swift`: 比赛实体与赛制。
- `Roster.swift`: 参赛位置指派记录。

## 开发规范
- 仅放值类型与基础协议，避免引入 SwiftUI 依赖。

## 变更日志
- 2026-02-04: 初始化模型层索引。
- 2026-02-04: 增加队伍头像样式与简介字段。

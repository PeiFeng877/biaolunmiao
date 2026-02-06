# BianLunMiao/Views/Team/AGENTS.md - 队伍页面索引

[PROTOCOL]: 变更时更新此头部，然后检查 AGENTS.md

**版本**: v1.0
**日期**: 2026-02-04

## 模块职责
- 定位: 队伍相关页面与弹窗的组合层。
- 边界: 仅做 UI 组合，业务逻辑交由 ViewModel。

## 目录结构
```
./BianLunMiao/Views/Team
├── AGENTS.md
├── CreateTeamSheet.swift
├── JoinTeamSheet.swift
├── MemberDetailView.swift
├── TeamDetailView.swift
├── TeamListView.swift
└── TeamRow.swift
```

## 文件职责
- `TeamListView.swift`: 队伍首页、空状态与创建/加入入口。
- `CreateTeamSheet.swift`: 创建/编辑队伍表单弹窗。
- `JoinTeamSheet.swift`: 通过队伍 ID 加入的弹窗。
- `TeamDetailView.swift`: 队伍详情与成员管理视图。
- `MemberDetailView.swift`: 队员个人详情与赛程展示。
- `TeamRow.swift`: 队伍列表行组件。

## 变更日志
- 2026-02-04: 初始化队伍页面索引。

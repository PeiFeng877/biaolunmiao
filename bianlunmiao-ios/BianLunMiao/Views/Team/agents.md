# BianLunMiao/Views/Team/agents.md - 队伍页面索引

[PROTOCOL]: 变更时更新此头部，然后检查 agents.md

**版本**: v1.2
**日期**: 2026-03-04

## 模块职责
- 定位: 队伍相关页面与弹窗的组合层。
- 边界: 仅做 UI 组合，业务逻辑交由 ViewModel。

## 目录结构
```
./BianLunMiao/Views/Team
├── agents.md
├── CreateTeamSheet.swift
├── JoinTeamSheet.swift
├── MemberDetailView.swift
├── TeamDetailView.swift
├── TeamListView.swift
├── TeamSearchView.swift
└── TeamRow.swift
```

## 文件职责
- `TeamListView.swift`: 队伍首页、空状态与创建/申请入口，负责将表单快照转换为创建 payload 并串起导航。
- `TeamSearchView.swift`: 队伍搜索页与申请入队弹窗流程。
- `CreateTeamSheet.swift`: 创建/编辑队伍表单弹窗，负责主线程提交、输入归一化与提交态反馈。
- `JoinTeamSheet.swift`: 通过队伍 ID 提交申请的弹窗。
- `TeamDetailView.swift`: 队伍详情与成员管理视图，负责将编辑表单快照转换为更新 payload。
- `MemberDetailView.swift`: 队员个人详情与赛程展示。
- `TeamRow.swift`: 队伍列表行组件。

## 变更日志
- 2026-03-04: 创建/编辑队伍弹窗新增 payload 快照、主线程保存闭包与提交态反馈，收紧队伍表单到 ViewModel 的并发边界。
- 2026-02-08: 统一入队入口为申请制，搜索页与 ID 入口都改为提交申请并等待审批。
- 2026-02-08: 新增 `TeamSearchView.swift`，支持按队名/队伍 ID 搜索与申请入队弹窗。
- 2026-02-04: 初始化队伍页面索引。

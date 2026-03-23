# BianLunMiao/ViewModels/Team/agents.md - 队伍视图模型索引

[PROTOCOL]: 变更时更新此头部，然后检查 agents.md

**版本**: v1.2
**日期**: 2026-03-23

## 模块职责
- 定位: 队伍主流程（列表、详情、成员）视图状态管理。
- 边界: 仅处理队伍领域，不承载赛事逻辑。

## 目录结构
```
./BianLunMiao/ViewModels/Team
├── agents.md
├── MemberDetailViewModel.swift
├── TeamDetailViewModel.swift
└── TeamListViewModel.swift
```

## 文件职责
- `TeamListViewModel.swift`: 队伍列表与申请入队入口状态，创建队伍时只转发归一化后的 payload 快照。
- `TeamDetailViewModel.swift`: 队伍详情与成员操作状态，编辑队伍时只转发归一化后的 payload 快照。
- `MemberDetailViewModel.swift`: 队员详情与历史记录状态。

## 变更日志
- 2026-03-23: `TeamDetailViewModel` 新增队内称呼编辑权限判定与更新入口，支撑本人/管理员成员称呼维护。
- 2026-03-04: 创建/编辑队伍链路改为主线程 payload 转发，补充调试日志，避免 UI 原始文本跨异步边界继续流动。
- 2026-02-08: `TeamListViewModel` 加入申请提交接口，移除直接入队语义。
- 2026-02-08: 从 `ViewModels` 根目录拆分 `Team` 子模块，降低单层复杂度。

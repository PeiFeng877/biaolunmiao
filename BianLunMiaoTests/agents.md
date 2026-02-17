# BianLunMiaoTests/agents.md - 单元测试索引

[PROTOCOL]: 变更时更新此头部，然后检查 agents.md

**版本**: v1.3
**日期**: 2026-02-16

## 模块职责
- 定位: 应用核心逻辑单元测试集合。
- 边界: 不承载 UI 自动化测试。

## 目录结构
```
./BianLunMiaoTests
├── agents.md
├── BianLunMiaoTests.swift
├── DesignGovernanceTests.swift
├── InboxScheduleProfileTests.swift
└── TeamJoinRequestFlowTests.swift
```

## 文件职责
- `BianLunMiaoTests.swift`: 默认单元测试入口样例。
- `DesignGovernanceTests.swift`: 设计治理脚本检查、生成一致性与违规拦截测试。
- `InboxScheduleProfileTests.swift`: 收件箱/日程/个人主页关键聚合逻辑测试。
- `TeamJoinRequestFlowTests.swift`: 入队申请提交、审批与消息聚合核心流程测试。

## 变更日志
- 2026-02-16: 补充 `InboxScheduleProfileTests.swift` 到测试索引，修复文档同构缺口。
- 2026-02-08: 新增 `DesignGovernanceTests.swift`，将按钮/提示治理审计纳入自动测试。
- 2026-02-08: 新增 `TeamJoinRequestFlowTests.swift`，覆盖申请制入队与审批消息闭环。
- 2026-02-08: 初始化测试模块索引，补齐 L2 文档层。

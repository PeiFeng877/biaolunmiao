# .github/agents.md - 自动化配置索引

[PROTOCOL]: 变更时更新此头部，然后检查 agents.md

**版本**: v1.2
**日期**: 2026-02-17

## 模块职责
- 定位: 存放仓库自动化流程配置。
- 边界: 仅包含 CI/CD 工作流定义，不包含业务代码。

## 目录结构
```
./.github
├── agents.md
└── workflows
    ├── agents.md
    ├── design-governance.yml
    └── full-regression.yml
```

## 文件职责
- `workflows/design-governance.yml`: PR/Push 快检门禁（治理、lint、单测、风险触发 UI 冒烟）。
- `workflows/full-regression.yml`: 主干与定时全量回归门禁。

## 变更日志
- 2026-02-17: CI 升级为“快检 + 全检”双轨执行，缩短日常改动反馈链路。
- 2026-02-16: 工作流补齐 SwiftFormat/SwiftLint 步骤，扩展为治理 + 静态 + 测试三道门禁。
- 2026-02-08: 新增设计治理工作流配置。

# .github/workflows/agents.md - CI 工作流索引

[PROTOCOL]: 变更时更新此头部，然后检查 agents.md

**版本**: v1.3
**日期**: 2026-03-19

## 模块职责
- 定位: 定义仓库自动化检查与阻断策略。
- 边界: 只管理 GitHub Actions workflow 文件。

## 目录结构
```
./.github/workflows
├── agents.md
├── design-governance.yml
├── full-regression.yml
└── specialized-ui.yml
```

## 文件职责
- `design-governance.yml`: 快检门禁（治理 + lint + 单测 + `smoke-local`）。
- `full-regression.yml`: 全检门禁（主干/夜间/手动触发，执行 `full-local`）。
- `specialized-ui.yml`: 启动截图、性能与素材产物专项，不阻断功能门禁。

## 变更日志
- 2026-03-19: CI 切换为 lane 驱动，快检改跑 `smoke-local`，主干健康改跑 `full-local`，新增 `specialized-ui.yml` 索引说明。
- 2026-02-17: 将 CI 升级为“快检 + 全检”双层执行模型，降低小改动反馈成本。
- 2026-02-16: CI 新增 SwiftFormat 与 SwiftLint 静态检查步骤，补齐通用代码质量门禁。
- 2026-02-08: 新增设计一致性治理 CI 流程。

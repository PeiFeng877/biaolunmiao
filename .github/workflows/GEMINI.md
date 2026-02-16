# .github/workflows/GEMINI.md - CI 工作流索引

[PROTOCOL]: 变更时更新此头部，然后检查 GEMINI.md

**版本**: v1.2
**日期**: 2026-02-17

## 模块职责
- 定位: 定义仓库自动化检查与阻断策略。
- 边界: 只管理 GitHub Actions workflow 文件。

## 目录结构
```
./.github/workflows
├── GEMINI.md
├── design-governance.yml
└── full-regression.yml
```

## 文件职责
- `design-governance.yml`: 快检门禁（治理 + lint + 单测 + 风险触发 UI 冒烟）。
- `full-regression.yml`: 全检门禁（主干/夜间/手动触发，执行全量回归）。

## 变更日志
- 2026-02-17: 将 CI 升级为“快检 + 全检”双层执行模型，降低小改动反馈成本。
- 2026-02-16: CI 新增 SwiftFormat 与 SwiftLint 静态检查步骤，补齐通用代码质量门禁。
- 2026-02-08: 新增设计一致性治理 CI 流程。

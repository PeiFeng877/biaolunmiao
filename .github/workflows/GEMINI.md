# .github/workflows/GEMINI.md - CI 工作流索引

[PROTOCOL]: 变更时更新此头部，然后检查 GEMINI.md

**版本**: v1.0
**日期**: 2026-02-08

## 模块职责
- 定位: 定义仓库自动化检查与阻断策略。
- 边界: 只管理 GitHub Actions workflow 文件。

## 目录结构
```
./.github/workflows
├── GEMINI.md
└── design-governance.yml
```

## 文件职责
- `design-governance.yml`: 在 PR/Push 执行治理审计与 `xcodebuild test`。

## 变更日志
- 2026-02-08: 新增设计一致性治理 CI 流程。

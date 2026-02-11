# .github/GEMINI.md - 自动化配置索引

[PROTOCOL]: 变更时更新此头部，然后检查 GEMINI.md

**版本**: v1.0
**日期**: 2026-02-08

## 模块职责
- 定位: 存放仓库自动化流程配置。
- 边界: 仅包含 CI/CD 工作流定义，不包含业务代码。

## 目录结构
```
./.github
├── GEMINI.md
└── workflows
    ├── GEMINI.md
    └── design-governance.yml
```

## 文件职责
- `workflows/design-governance.yml`: 设计治理审计与单元测试的 CI 阻断流程。

## 变更日志
- 2026-02-08: 新增设计治理工作流配置。

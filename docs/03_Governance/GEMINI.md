# docs/03_Governance/GEMINI.md - 设计治理模块

[PROTOCOL]: 变更时更新此头部，然后检查 GEMINI.md

**版本**: v1.2
**日期**: 2026-02-17

## 模块职责
- 定位: 统一维护按钮与提示组件的设计规范、应用清单与自动审计机制。
- 边界: 仅记录治理规则与生成结果，不承载业务需求文档。

## 目录结构
```
./docs/03_Governance
├── GEMINI.md
├── Button_Component_Spec.md
├── Button_Usage_Inventory.md
├── Feedback_Component_Spec.md
├── Feedback_Usage_Inventory.md
├── Unified_Standards_Matrix.md
├── Unified_Standards_Audit_Report.md
├── Unified_Remediation_Backlog.md
├── Testing_Execution_Policy.md
├── design-evidence
│   ├── README.md
│   ├── runtime-summary.tsv
│   ├── logs
│   └── screenshots
└── tools
    └── governance_audit.swift
```

## 文件职责
- `Button_Component_Spec.md`: 按钮设计规范（允许的样式、状态、约束）。
- `Button_Usage_Inventory.md`: 按钮实际使用清单（自动生成）。
- `Feedback_Component_Spec.md`: 提示体系规范（Toast/Alert/Dialog/Sheet 语义边界）。
- `Feedback_Usage_Inventory.md`: 提示实际使用清单（自动生成）。
- `Unified_Standards_Matrix.md`: 双轨标准矩阵（项目硬门槛 + iOS skills 最佳实践）。
- `Unified_Standards_Audit_Report.md`: 全量体检报告与分级问题结论。
- `Unified_Remediation_Backlog.md`: 两周整改排期与可执行验收命令。
- `Testing_Execution_Policy.md`: 测试执行分层策略（快检 + 全检）与触发规则。
- `design-evidence/*`: 审计证据归档（运行态汇总、命令日志、截图）。
- `tools/governance_audit.swift`: 一致性扫描、违规拦截、Inventory 生成脚本。

## 开发规范
- Inventory 文件禁止手工编辑，必须由脚本生成。
- 新增按钮或提示组件时，先更新 Spec，再更新实现，再运行审计脚本。
- 审计失败视为架构不一致，必须在合并前修复。

## 变更日志
- 2026-02-17: 新增 `Testing_Execution_Policy.md`，固化测试分层执行策略与后续演进路线。
- 2026-02-16: 新增统一规范治理三件套（矩阵/审计报告/整改清单）与 `design-evidence` 证据目录。
- 2026-02-08: 新增按钮/提示治理模块，接入自动审计与清单生成。

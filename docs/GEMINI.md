# docs/GEMINI.md - 文档体系索引

[PROTOCOL]: 变更时更新此头部，然后检查 GEMINI.md

**版本**: v1.3
**日期**: 2026-02-16

## 模块职责

- 定位: 统一承载产品与技术文档，作为项目的语义相记录。
- 边界: 文档结构与代码结构同构，新增/变更必须同步。

## 目录结构

```
./docs
├── GEMINI.md
├── 01_Product
│   ├── GEMINI.md
│   ├── PRD_Core_Logic_Rules.md
│   ├── PRD_Team_Interaction_UX.md
│   ├── PRD_Tournament_Interaction_MVP.md
│   └── Design_System_BianLunMiao.md
├── 02_Tech
│   ├── GEMINI.md
│   ├── API_Specification.md
│   ├── DB_Schema_Detailed.md
│   └── Technical_Architecture_Plan.md
└── 03_Governance
    ├── GEMINI.md
    ├── Button_Component_Spec.md
    ├── Button_Usage_Inventory.md
    ├── Feedback_Component_Spec.md
    ├── Feedback_Usage_Inventory.md
    ├── Unified_Standards_Matrix.md
    ├── Unified_Standards_Audit_Report.md
    ├── Unified_Remediation_Backlog.md
    ├── design-evidence
    │   ├── README.md
    │   ├── runtime-summary.tsv
    │   ├── logs
    │   └── screenshots
    └── tools
        └── governance_audit.swift
```

## 文件职责

- `01_Product/GEMINI.md`: 产品文档索引与边界说明。
- `02_Tech/GEMINI.md`: 技术文档索引与边界说明。
- `03_Governance/GEMINI.md`: 设计一致性治理索引与自动审计入口。
- `03_Governance/Unified_Standards_Matrix.md`: 双轨标准矩阵与规则编号。
- `03_Governance/Unified_Standards_Audit_Report.md`: 统一规范体检总报告。
- `03_Governance/Unified_Remediation_Backlog.md`: 统一整改清单与批次排期。
- `03_Governance/design-evidence/*`: 审计证据归档（日志、汇总、截图）。

## 架构决策

- 文档按业务与技术分层，产品与技术互不掺杂。

## 开发规范

- 新增/删除文档需同步更新本文件与对应子模块 `GEMINI.md`。
- 文档必须包含版本与日期。
- 自动生成文档必须标记来源脚本并禁止手工维护。

## 变更日志

- 2026-02-16: 新增统一规范治理三件套与 `design-evidence` 证据目录。
- 2026-02-08: 新增 `03_Governance` 治理模块，接入按钮/提示一致性自动审计。
- 2026-02-04: 补齐 02_Tech 索引并规范头部信息。

# docs/GEMINI.md - 文档体系索引

[PROTOCOL]: 变更时更新此头部，然后检查 GEMINI.md

**版本**: v1.2
**日期**: 2026-02-08

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
    └── tools
        └── governance_audit.swift
```

## 文件职责

- `01_Product/GEMINI.md`: 产品文档索引与边界说明。
- `02_Tech/GEMINI.md`: 技术文档索引与边界说明。
- `03_Governance/GEMINI.md`: 设计一致性治理索引与自动审计入口。

## 架构决策

- 文档按业务与技术分层，产品与技术互不掺杂。

## 开发规范

- 新增/删除文档需同步更新本文件与对应子模块 `GEMINI.md`。
- 文档必须包含版本与日期。
- 自动生成文档必须标记来源脚本并禁止手工维护。

## 变更日志

- 2026-02-08: 新增 `03_Governance` 治理模块，接入按钮/提示一致性自动审计。
- 2026-02-04: 补齐 02_Tech 索引并规范头部信息。

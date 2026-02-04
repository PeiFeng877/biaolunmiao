# docs/AGENTS.md - 文档体系索引

[PROTOCOL]: 变更时更新此头部，然后检查 AGENTS.md

**版本**: v1.1
**日期**: 2026-02-04

## 模块职责

- 定位: 统一承载产品与技术文档，作为项目的语义相记录。
- 边界: 文档结构与代码结构同构，新增/变更必须同步。

## 目录结构

```
./docs
├── AGENTS.md
├── 01_Product
│   ├── AGENTS.md
│   ├── PRD_Core_Logic_Rules.md
│   ├── PRD_Team_Interaction_UX.md
│   ├── PRD_Tournament_Interaction_MVP.md
│   └── Design_System_BianLunMiao.md
└── 02_Tech
    ├── AGENTS.md
    ├── API_Specification.md
    ├── DB_Schema_Detailed.md
    └── Technical_Architecture_Plan.md
```

## 文件职责

- `01_Product/AGENTS.md`: 产品文档索引与边界说明。
- `02_Tech/AGENTS.md`: 技术文档索引与边界说明。

## 架构决策

- 文档按业务与技术分层，产品与技术互不掺杂。

## 开发规范

- 新增/删除文档需同步更新本文件与对应子模块 `AGENTS.md`。
- 文档必须包含版本与日期。

## 变更日志

- 2026-02-04: 补齐 02_Tech 索引并规范头部信息。

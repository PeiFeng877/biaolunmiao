# docs/agents.md - iOS 专属文档索引

[PROTOCOL]: 变更时更新此头部，然后检查 agents.md

**版本**: v2.0
**日期**: 2026-02-17

## 模块职责
- 定位: 仅存放 iOS 端专属规范文档。
- 边界: 跨端产品、架构、接口、发布规范统一维护在根目录 `docs/`。

## 目录结构
```text
./docs
├── agents.md
├── 01_Product
│   ├── agents.md
│   └── 设计系统_辩论喵iOS.md
└── 03_Governance
    ├── agents.md
    ├── 按钮组件规范.md
    ├── 按钮使用清单.md
    ├── 反馈组件规范.md
    ├── 反馈使用清单.md
    ├── 测试执行策略.md
    └── tools
        └── governance_audit.swift
```

## 文件职责
- `01_Product/设计系统_辩论喵iOS.md`: iOS 视觉与组件设计系统。
- `03_Governance/按钮组件规范.md`: iOS 按钮规范白名单。
- `03_Governance/反馈组件规范.md`: iOS 反馈组件规范白名单。
- `03_Governance/按钮使用清单.md`: 按钮使用清单（脚本生成）。
- `03_Governance/反馈使用清单.md`: 反馈使用清单（脚本生成）。
- `03_Governance/测试执行策略.md`: iOS 端测试执行分层策略。
- `03_Governance/tools/governance_audit.swift`: 治理扫描与清单生成脚本。

## 开发规范
- 新增/删除 iOS 文档时，必须同步更新本文件及子目录 `agents.md`。
- Inventory 文档禁止手工维护，必须由脚本生成。

## 变更日志
- 2026-02-17: 完成文档收敛，移除重复的跨端文档，保留 iOS 专属文档。

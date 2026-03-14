# docs/agents.md - iOS 专属文档索引

[PROTOCOL]: 变更时更新此头部，然后检查 agents.md

**版本**: v2.2
**日期**: 2026-03-06

## 模块职责
- 定位: 仅存放 iOS 端专属规范文档。
- 边界: 跨端产品、架构、接口、发布规范统一维护在根目录 `docs/`。

## 目录结构
```text
./docs
├── agents.md
├── 01_Product
│   ├── agents.md
│   ├── 账号删除审核整改方案.md
│   └── 设计系统_辩论喵iOS.md
├── 02_assets
│   └── ezgif-4487913e805779b4.png
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
- `01_Product/账号删除审核整改方案.md`: App Review 拒信、中文翻译、账号删除交互方案与实施清单。
- `01_Product/设计系统_辩论喵iOS.md`: iOS 视觉与组件设计系统。
- `02_assets/ezgif-4487913e805779b4.png`: iOS 设计与上架素材中间产物，作为设计资源留档，不作为 SSOT 文案。
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
- 2026-03-06: 新增 `01_Product/账号删除审核整改方案.md`，沉淀账号删除审核拒绝原文、翻译与整改方案。
- 2026-03-04: 补充 `02_assets` 资源目录索引，修正文档中心与真实目录结构不一致问题。
- 2026-02-17: 完成文档收敛，移除重复的跨端文档，保留 iOS 专属文档。

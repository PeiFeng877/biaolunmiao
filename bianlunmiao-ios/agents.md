# agents.md

[PROTOCOL]: 变更时更新此头部，然后检查 agents.md

**版本**: v1.0
**日期**: 2026-03-04
**适用范围**: `/Users/Icarus/Documents/project/bianlunmiao/bianlunmiao-ios`

## 1. 模块职责
1. 本目录是 iOS 客户端主工程，承载 SwiftUI 应用、测试、治理脚本与 iOS 专属文档。
2. 跨端规范以根目录 `docs/` 为准；本目录只维护 iOS 实现与 iOS 专属治理细则。
3. 构建产物与回归证据可落在 `build/`、`artifacts/`，但不作为 SSOT。

## 2. 目录结构
```text
./bianlunmiao-ios
├── agents.md
├── .github/
│   ├── agents.md
│   └── workflows/
├── BianLunMiao/
│   ├── agents.md
│   ├── Data/
│   ├── DesignSystem/
│   ├── Models/
│   ├── ViewModels/
│   └── Views/
├── BianLunMiao.xcodeproj/
├── BianLunMiao.entitlements
├── BianLunMiaoTests/
│   └── agents.md
├── BianLunMiaoUITests/
│   └── agents.md
├── docs/
│   ├── agents.md
│   ├── 01_Product/
│   ├── 02_assets/
│   └── 03_Governance/
├── fal_inputs/
│   └── agents.md
├── .agent/
│   ├── skills/
│   └── workflows/
├── build/
└── artifacts/
```

## 3. 边界约束
1. `BianLunMiao/` 仅放客户端运行时代码，不放发布资料与临时脚本。
2. `docs/` 仅放 iOS 专属规范；协议、联调、发布总规范统一写入根目录 `docs/`。
3. `build/` 与 `artifacts/` 视为生成物目录，内容可更新，但目录结构变化不替代 SSOT 文档更新。
4. `BianLunMiao.entitlements`、版本号、权限文案与上架资料变更时，必须同步检查根目录 `docs/04_测试与发布/`。

## 4. 质量门禁
1. 治理检查：`swift docs/03_Governance/tools/governance_audit.swift --mode check`
2. iOS 测试：按 `docs/03_Governance/测试执行策略.md` 与根目录 `docs/04_测试与发布/01_测试执行策略.md` 执行。
3. 发布前必须复核 `MARKETING_VERSION`、`CURRENT_PROJECT_VERSION`、Bundle ID、Capability、隐私与提审资料一致性。

## 变更日志
- 2026-03-04: 按主仓协作宪章重写 iOS 根 `agents.md`，补齐目录边界、生成物约束与发布门禁说明。

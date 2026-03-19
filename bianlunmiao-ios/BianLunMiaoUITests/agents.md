# BianLunMiaoUITests/agents.md - UI 测试索引

[PROTOCOL]: 变更时更新此头部，然后检查 agents.md

**版本**: v2.0
**日期**: 2026-03-19

## 模块职责
- 定位: 应用 UI 与启动流程自动化测试集合。
- 边界: 仅包含 UI 测试，不写业务实现代码。

## 目录结构
```
./BianLunMiaoUITests
├── agents.md
├── BianLunMiaoUITestSupport.swift
├── BianLunMiaoSmokeLocalUITests.swift
├── BianLunMiaoFunctionalUITests.swift
├── BianLunMiaoLocalRemoteUITests.swift
├── BianLunMiaoSTGSmokeUITests.swift
├── BianLunMiaoDeviceSpecialUITests.swift
├── BianLunMiaoSpecializedUITests.swift
└── BianLunMiaoUITestsLaunchTests.swift
```

## 文件职责
- `BianLunMiaoUITestSupport.swift`: UI 测试公共启动、等待、lane 约束与诊断支持。
- `BianLunMiaoSmokeLocalUITests.swift`: 默认 `smoke-local` 冒烟用例。
- `BianLunMiaoFunctionalUITests.swift`: `full-local` 长链路功能回归。
- `BianLunMiaoLocalRemoteUITests.swift`: 本机后端联调用例。
- `BianLunMiaoSTGSmokeUITests.swift`: `STG` 只读健康冒烟。
- `BianLunMiaoDeviceSpecialUITests.swift`: 真机专项用例。
- `BianLunMiaoSpecializedUITests.swift`: App Store 截图与启动性能专项。
- `BianLunMiaoUITestsLaunchTests.swift`: Launch screenshot 专项。

## 变更日志
- 2026-03-19: UI 自动化按 lane 拆分为 smoke/full-local/local-remote/stg-smoke/device-special/specialized，移除单文件大杂烩入口。
- 2026-02-08: 初始化 UI 测试索引，补齐 L2 文档层。

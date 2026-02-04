# BianLunMiao/Data/AGENTS.md - 数据层索引

[PROTOCOL]: 变更时更新此头部，然后检查 AGENTS.md

**版本**: v1.0
**日期**: 2026-02-04

## 模块职责
- 定位: 维护应用状态与本地 Mock 数据。
- 边界: 不包含 UI 与视图逻辑。

## 目录结构
```
./BianLunMiao/Data
├── AGENTS.md
├── AppStore.swift
└── MockData.swift
```

## 文件职责
- `AppStore.swift`: 应用状态容器与领域操作入口。
- `MockData.swift`: 本地 Mock 数据与初始化脚本。

## 开发规范
- 对外只暴露数据操作接口，避免视图层访问内部细节。

## 变更日志
- 2026-02-04: 初始化数据层索引。

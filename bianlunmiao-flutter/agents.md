# agents.md

[PROTOCOL]: 变更时更新此头部，然后检查 agents.md

**版本**: v1.0
**日期**: 2026-02-24
**适用范围**: `/Users/Icarus/Documents/project/bianlunmiao/bianlunmiao-flutter`

## 1. 模块目标
1. 承载辩论喵 Flutter 客户端实现，优先覆盖 Android 端现有功能。
2. 保持与 iOS 现有视觉与交互同构，作为后续统一替换 iOS 客户端的候选实现。

## 2. 目录与边界
1. 本目录仅放 Flutter 客户端代码与 Flutter 专属文档。
2. 跨端契约、PRD、接口规范继续以根目录 `docs/` 为 SSOT。
3. 禁止在本目录重复维护与 `docs/` 冲突的接口契约副本。

## 3. 开发约束
1. 先对齐现有 `docs/03_接口与数据契约/`，再接入接口。
2. 视觉与交互以 iOS 现状为基线，不得先行改动产品语义。
3. 结构变更（新增/删除/重命名）必须同步更新本文件与父级 `agents.md`。

## 4. 质量门禁
1. `flutter analyze`
2. `flutter test`
3. `flutter build apk --debug`

## 变更日志
- 2026-02-24: 初始化 Flutter 模块协作约束，作为 Android 包替换起点。

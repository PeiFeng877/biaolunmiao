# Design Evidence Bundle

[PROTOCOL]: 变更时更新此头部，然后检查 GEMINI.md

**版本**: v1.0  
**日期**: 2026-02-16  
**用途**: 统一规范体检的运行态与静态证据归档。

## 目录说明
- `runtime-summary.tsv`: 五模块运行态检查结果汇总。
- `logs/`: 命令级日志与扫描结果（治理检查、测试、扫描输出）。
- `screenshots/`: 运行态截图产物（当前含 Team 手动截图）。

## 当前限制
- 通过 `xcodebuild test` 执行 UI 用例时，测试运行在克隆模拟器上下文中，`simctl` 对该上下文截图稳定性不足。
- 当前已保留五模块测试通过日志，并补充 Team 手动截图作为运行态视觉证据。
- 后续建议: 新增专用截图 helper（在 UI 测试内落盘）或接入 XcodeBuildMCP/IDB 以稳定采图。


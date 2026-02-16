# Unified Remediation Backlog

[PROTOCOL]: 变更时更新此头部，然后检查 GEMINI.md

**版本**: v1.2  
**日期**: 2026-02-17  
**来源**: `Unified_Standards_Audit_Report.md`  
**状态**: 本轮 P0/P1 全部完成

## 1. 状态定义
- `DONE`: 已落地并通过验收命令。
- `FOLLOW-UP`: 已纳入后续迭代优化，不影响当前基线通过。

## 2. 整改清单（执行结果）
| ID | 优先级 | 状态 | 问题 | 证据 | 规则 | 已落实动作 | 验收命令 |
| --- | --- | --- | --- | --- | --- | --- | --- |
| RB-001 | P0 | DONE | `.buttonStyle(.plain)` 违规 | `governance_check_after.log` | `DES-001` | 违规点替换为 `AppRowTapButton`/设计系统入口 | `swift docs/03_Governance/tools/governance_audit.swift --mode check` |
| RB-002 | P0 | DONE | 治理违规阻断单测 | `unit_tests_after.log` | `TST-001` | 修复治理后回归 `BianLunMiaoTests` 全绿 | `xcodebuild test -scheme BianLunMiao -destination 'platform=iOS Simulator,name=iPhone 17,OS=26.2' -only-testing:BianLunMiaoTests` |
| RB-003 | P1 | DONE | `BianLunMiaoTests/GEMINI` 同构缺口 | 文件变更记录 | `DOC-002` | 补齐 `InboxScheduleProfileTests.swift` 索引 | `rg -n "InboxScheduleProfileTests.swift" BianLunMiaoTests/GEMINI.md` |
| RB-004 | P1 | DONE | `docs/02_Tech` 缺 `[PROTOCOL]` | 文件变更记录 | `DOC-001` | 三份技术文档补齐协议头 | `for f in docs/02_Tech/*.md; do rg -q "\[PROTOCOL\]" "$f" || echo "$f"; done` |
| RB-005 | P1 | DONE | `AppStore.swift`/`ScheduleView.swift` 超长 | `compliance_scan_after.log` | `DOC-005`,`COD-006` | 拆分为 `AppStore+TeamHelpers.swift`、`ScheduleView+CalendarSync.swift`、`Components/ScheduleBatchSyncSheet.swift` | `wc -l BianLunMiao/Data/AppStore.swift BianLunMiao/Views/Schedule/ScheduleView.swift` |
| RB-006 | P1 | DONE | `Models` 单层文件超限 | `compliance_scan_after.log` | `DOC-005` | `InboxMessage.swift` 下沉至 `Models/Message/` | `find BianLunMiao/Models -maxdepth 1 -type f | wc -l` |
| RB-007 | P1 | DONE | 旧 API `foregroundColor` 残留 | `compliance_scan_after.log` | `DES-004`,`COD-004` | 目标范围内迁移为 `foregroundStyle` | `rg -n "foregroundColor\(" BianLunMiao -g '*.swift'` |
| RB-008 | P1 | DONE | ViewModel actor 策略不统一 | `compliance_scan_after.log` | `COD-005`,`CON-001` | 11 个 ViewModel 补齐 `@MainActor` | `rg -n "@MainActor" BianLunMiao/ViewModels -g '*.swift'` |
| RB-009 | P1 | DONE | 运行态证据链整理 | `runtime-summary.tsv` | `DES-007` | 五模块运行态记录归档 + Team 手动截图证据 | `cat docs/03_Governance/design-evidence/runtime-summary.tsv` |
| RB-010 | P2 | DONE | 缺少通用静态工具链 | `.swiftlint.yml`, `.swiftformat`, CI 变更 | `TST-005` | 接入 SwiftFormat/SwiftLint（告警可见模式） | `swiftformat BianLunMiao BianLunMiaoTests BianLunMiaoUITests --lint --lenient && swiftlint lint --config .swiftlint.yml` |
| RB-011 | P2 | FOLLOW-UP | Team 专项 UI 场景可再细化 | 当前 `testExample` 覆盖有限 | `TST-003` | 已有 UITest 冒烟通过，后续可拆 Team 细化流 | `xcodebuild test -scheme BianLunMiao -destination 'platform=iOS Simulator,name=iPhone 17,OS=26.2' -only-testing:BianLunMiaoUITests/testExample` |
| RB-012 | P2 | FOLLOW-UP | 测试参数化空间 | 现有测试重复逻辑 | `TST-004` | 本轮不阻断；后续按模块推进参数化 | `xcodebuild test -scheme BianLunMiao -destination 'platform=iOS Simulator,name=iPhone 17,OS=26.2' -only-testing:BianLunMiaoTests` |
| RB-013 | P1 | DONE | 小改动测试反馈链路偏长 | 原 CI 执行全量测试 | `TST-007` | 新增 `quick-ci` + `full-ci` 双层流程，PR 走快检，主干/夜间走全检 | `gh workflow list` / 查看 `.github/workflows/*.yml` |

## 3. 退出标准检查
- P0 项: 完成。
- P1 项: 完成。
- `governance_audit --mode check`: 通过。
- `BianLunMiaoTests`: 通过。
- 选定 `BianLunMiaoUITests` 冒烟: 通过。

## 4. 下一轮建议
- 目标: 在不影响主干稳定性的前提下，逐步清理 SwiftFormat/SwiftLint 告警并升级为阻断模式。
- 基于 `Testing_Execution_Policy.md` 逐步扩展 UI 冒烟白名单并引入自动截图归档。

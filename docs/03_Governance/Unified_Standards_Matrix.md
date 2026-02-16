# Unified Standards Matrix

[PROTOCOL]: 变更时更新此头部，然后检查 GEMINI.md

**版本**: v1.1  
**日期**: 2026-02-17  
**范围**: `BianLunMiao` iOS 项目的文档、设计系统、代码、测试、并发治理。

## 1. 基线定义
- **硬门槛（Hard Gate）**: 项目内现有规范（`GEMINI.md`、`governance_audit.swift`、CI 与测试基线）。
- **改进上限（Best Practice）**: iOS skills（`ios-mvvm`、`ios-design-guidelines`、`mobile-ios-design`、`swiftui-expert-skill`、`swift-testing-expert`、`swift-concurrency-expert`）。

## 2. 规则矩阵
| Rule ID | 分类 | 级别 | 来源 | 严重级别 | 自动化可行性 | 检查方法 | 通过条件 | 修复模板 |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| DOC-001 | 文档 | Hard Gate | `GEMINI` / GEB 协议 | P1 | 高 | 扫描 `.md/.swift` 是否含 `[PROTOCOL]` | 全量覆盖 | 为缺失文件补齐 `[PROTOCOL]` 头并更新版本日期 |
| DOC-002 | 文档 | Hard Gate | `GEMINI` 同构规则 | P1 | 中 | 对比目录树与各层 `GEMINI.md` | 无漏登/错登文件 | 更新对应模块 `GEMINI.md` 的目录树与职责清单 |
| DOC-003 | 文档 | Hard Gate | `docs/GEMINI.md` 规范 | P2 | 中 | 检查文档头部版本/日期/变更日志 | 关键文档具备版本化信息 | 补齐版本、日期、变更日志 |
| DOC-004 | 文档 | Hard Gate | `03_Governance` 规范 | P1 | 高 | 检查 Inventory 是否由脚本生成 | 与 `--mode generate` 一致 | 运行生成脚本并提交更新结果 |
| DOC-005 | 文档+结构 | Hard Gate | 根 `GEMINI` 质量约束 | P1 | 高 | 检查单文件行数、单层文件数 | 文件 <= 800 行；单层 <= 8 文件 | 拆分超大文件/拆分目录层级 |
| DOC-006 | 文档 | Best Practice | `ios-mvvm` | P2 | 低 | 架构变更后文档是否同步 | 架构变更同提交包含文档变更 | 将文档更新加入 PR 必选项 |
| DES-001 | 设计 | Hard Gate | `governance_audit.swift` | P0 | 高 | `swift docs/03_Governance/tools/governance_audit.swift --mode check` | 无 `no-plain-button-style` 等违规 | 使用 `AppRowTapButton` 或 DesignSystem 样式替代 |
| DES-002 | 设计 | Hard Gate | `Feedback_Component_Spec.md` | P0 | 高 | 扫描 `.alert/.sheet/.confirmationDialog` | 业务层仅调用 `app*` API | 替换为 `appAlert/appSheet/appConfirmationDialog` |
| DES-003 | 设计 | Hard Gate | `Button_Component_Spec.md` | P0 | 高 | 扫描裸 `Button(` 与白名单组件 | 仅使用白名单入口 | 替换为 `AppButton/AppIconButton/...` |
| DES-004 | 设计 | Best Practice | `swiftui-expert-skill` | P1 | 中 | 扫描 `foregroundColor/cornerRadius` 旧 API | 新增代码优先现代 API | 迁移到 `foregroundStyle/clipShape` |
| DES-005 | 设计 | Best Practice | `ios-design-guidelines` | P1 | 中 | 检查交互元素最小点击区 44pt | 关键交互可点击区满足 44pt | 为小交互补 `frame(minWidth:minHeight:)` |
| DES-006 | 设计 | Best Practice | `mobile-ios-design` | P2 | 低 | 导航结构审计 | 顶层使用 Tab/NavigationStack | 清理非 iOS 习惯导航模式 |
| DES-007 | 设计 | Best Practice | `ios-design-guidelines` | P1 | 中 | 可访问性标识/标签扫描 + UI 冒烟 | 关键操作可被 UI 测试稳定定位 | 为关键组件补 identifier / label |
| COD-001 | 代码 | Hard Gate | `ios-mvvm` / 项目 `GEMINI` | P1 | 高 | 扫描 `Models` 是否 import SwiftUI | Model 层无 UI 依赖 | 下沉 UI 相关逻辑到 View/ViewModel |
| COD-002 | 代码 | Best Practice | `ios-mvvm` | P1 | 中 | View 中网络/持久化副作用扫描 | 副作用集中在 Store/Service | 将副作用迁移到 ViewModel/Store |
| COD-003 | 代码 | Best Practice | `swiftui-expert-skill` | P1 | 中 | 状态包装器与数据流检查 | `@StateObject/@ObservedObject` 用法合理 | 统一 state ownership 并减少 fan-out |
| COD-004 | 代码 | Best Practice | `swiftui-expert-skill` | P1 | 中 | 旧 API、布局硬编码、大型 View 检查 | 新代码现代 API，布局语义化 | 分段迁移 API 与提取子视图 |
| COD-005 | 代码 | Best Practice | `swift-concurrency-expert` | P1 | 中 | ViewModel actor 隔离与 async 使用检查 | UI 相关状态更新具备明确隔离 | 关键 ViewModel 标注 `@MainActor` 或显式隔离 |
| COD-006 | 代码 | Hard Gate | 根 `GEMINI` 质量约束 | P1 | 高 | 超长文件与复杂区块扫描 | 不触发硬限制或有拆分计划 | 将超长文件按域拆分 |
| TST-001 | 测试 | Hard Gate | CI + `DesignGovernanceTests` | P0 | 高 | `xcodebuild test -only-testing:BianLunMiaoTests` | 核心单测全绿 | 先修治理违规再重跑单测 |
| TST-002 | 测试 | Best Practice | `swift-testing-expert` | P1 | 中 | Swift Testing 与 XCTest 职责分层 | 单测优先 `Testing`，UI 测试保留 XCTest | 新单测优先 `@Test + #expect` |
| TST-003 | 测试 | Hard Gate | 项目 MVP 要求 | P1 | 中 | 关键流程覆盖（队伍/赛事/日程/消息/我的） | 至少一条可执行用例/模块 | 为缺口模块补冒烟 UI 测试 |
| TST-004 | 测试 | Best Practice | `swift-testing-expert` | P2 | 中 | 重复断言、参数化机会检查 | 可复用测试参数化 | 抽取参数化 `@Test(arguments:)` |
| TST-005 | 测试 | Hard Gate | `design-governance.yml` | P1 | 高 | 检查 CI 是否阻断治理违规 | PR 中治理违规应失败 | 保持治理检查为必过项 |
| TST-006 | 测试 | Best Practice | `swift-testing-expert` | P2 | 低 | 并行安全与串行化理由检查 | 默认并行安全，串行有理由 | 对共享状态隔离，减少 `.serialized` 依赖 |
| TST-007 | 测试流程 | Hard Gate | CI 分层策略 | P1 | 高 | 校验 PR 快检与主干全检是否都存在 | PR 不跑全回归，主干保留全回归 | 采用“双层 workflow + 风险触发 UI 冒烟” |
| CON-001 | 并发 | Best Practice | `swift-concurrency-expert` | P1 | 中 | 检查 `@MainActor`、异步边界 | UI 更新位于主 actor 语义内 | 为 UI-bound 类型补 actor 隔离 |
| CON-002 | 并发 | Best Practice | `swift-concurrency-expert` | P2 | 低 | Sendable 与全局可变状态扫描 | 不引入数据竞争风险 | 采用值语义/actor 包装共享可变状态 |
| CON-003 | 并发 | Best Practice | `swiftui-expert-skill` | P2 | 中 | `.task`/取消语义检查 | 异步任务可取消且与视图生命周期对齐 | 优先 `.task` 和 `.task(id:)` |

## 3. 推荐统一入口命令（下一轮自动化）
```bash
swift docs/03_Governance/tools/unified_audit.swift --scope all --mode check --format markdown
```

## 4. 测试执行策略（当前生效）
- 快检（PR/Push）:
  - 治理检查 + SwiftFormat/SwiftLint + `BianLunMiaoTests`。
  - 当改动触发 UI 风险路径时，追加 UI 冒烟。
- 全检（main/master push + nightly + manual）:
  - 治理检查 + 静态检查 + 全量 `xcodebuild test`。

# BianLunMiao/Data/agents.md - 数据层索引

[PROTOCOL]: 变更时更新此头部，然后检查 agents.md

**版本**: v1.15
**日期**: 2026-03-22

## 模块职责
- 定位: 维护应用状态、鉴权门禁与远端快照同步。
- 边界: 不包含 UI 与视图逻辑。

## 目录结构
```
./BianLunMiao/Data
├── agents.md
├── AppStore+TeamHelpers.swift
├── AppStore.swift
├── MockData.swift
├── RemoteGateway.swift
└── RuntimeOverrides.swift
```

## 文件职责
- `AppStore.swift`: 应用状态容器、登录状态机、登录后落点分流、调试态首登强制开关与核心领域操作入口（队伍创建/编辑改为不可变 payload 快照驱动，远端快照合并时按队伍 ID 去重）。
- `AppStore+TeamHelpers.swift`: 团队关联维护、头像落盘与权限判定扩展方法。
- `MockData.swift`: 仅供 Preview/测试边界复用的本地 Mock 数据与初始化脚本。
- `RemoteGateway.swift`: 远程接口网关、REST 到 RPC 的动作映射、Apple 登录换票、首登标记消费、会话续签与全量快照拉取；运行态默认只保留 `local/prod`，当前 `prod` 默认指向已落地的 FC 默认域名，并支持通过 `BLM_API_BASE_URL` 或 `BLM_PROD_API_BASE_URL` 显式覆盖。
- `RuntimeOverrides.swift`: 统一解析环境变量与启动参数，供 UI 自动化、Maestro 与调试场景复用。

## 开发规范
- 对外只暴露数据操作接口，避免视图层访问内部细节。
- Release 路径禁止依赖 `MockData` 和环境变量注入身份令牌直接进入业务流。
- 表单输入归一化只在 UI 快照阶段做一次，`AppStore` 只接收已校验的 payload，不重复读取原始文本状态。

## 变更日志
- 2026-03-22: `RemoteGateway` 收口为 `local/prod` 两态，正式基址改为已落地的 FC 默认域名，去除 `stg` 现行依赖。
- 2026-03-19: 新增 `RuntimeOverrides.swift`，统一承接环境变量与启动参数覆盖，避免 UI 测试和第三方自动化重复分叉。
- 2026-03-19: 为真机 Debug 直连当前 HTTP staging，补充 Debug-only ATS 放宽约束；Release 继续保持正式 HTTPS。
- 2026-03-19: `RemoteGateway` 收敛 Debug 默认基址策略，改为“模拟器 localhost / 真机 staging”，同时保留 `BLM_API_BASE_URL` 显式覆盖。
- 2026-03-06: 新增账号删除链路，`AppStore`/`RemoteGateway` 支持删除账号请求、已删除账号错误映射与会话清理。
- 2026-03-04: 为便于当前阶段在 Release 构建联调，临时将“强制新用户资料流”提升为全构建生效；回归完成后需回收。
- 2026-03-04: Debug 下“强制新用户资料流”默认开启，便于当前阶段直接回归登录后资料完善流程。
- 2026-03-04: `AppStore` 新增 Debug 用“强制新用户资料流”开关，老账号可在下次登录时直接进入资料完善页。
- 2026-03-04: Apple 登录链路消费后端 `isNewUser`；`AppStore` 新增登录后落点状态，新用户先完成资料页再进入主容器。
- 2026-03-04: 队伍创建/编辑接口改为 `TeamCreatePayload`/`TeamUpdatePayload`，补充创建链路调试日志并修复远端快照重复队伍 ID 的崩溃风险。
- 2026-03-02: `AppStore` 新增鉴权状态机与启动门禁，关键写操作改为远端成功后刷新本地快照；`RemoteGateway` 增加 Apple 登录换票并关闭 Release 环境令牌注入兜底。
- 2026-02-26: 纳入 `RemoteGateway.swift`，补齐数据层远程网关职责描述与目录映射。
- 2026-02-20: 发布前收敛会话与种子策略，Release 默认关闭本地 Mock 种子并禁用 debug-token 自动建会话。
- 2026-02-16: 新增 `AppStore+TeamHelpers.swift`，拆分团队辅助逻辑并将 `AppStore.swift` 控制到 800 行内。
- 2026-02-16: `updateCurrentUserProfile` 增加头像写入能力，支持用户头像文件落盘与快照同步。
- 2026-02-08: 新增入队申请状态存储与审批接口，补齐消息页 Mock 数据。
- 2026-02-04: 初始化数据层索引。
- 2026-02-04: 增加队伍创建/加入/移交等领域操作。

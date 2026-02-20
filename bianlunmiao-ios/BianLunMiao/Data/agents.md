# BianLunMiao/Data/agents.md - 数据层索引

[PROTOCOL]: 变更时更新此头部，然后检查 agents.md

**版本**: v1.4
**日期**: 2026-02-20

## 模块职责
- 定位: 维护应用状态与本地 Mock 数据。
- 边界: 不包含 UI 与视图逻辑。

## 目录结构
```
./BianLunMiao/Data
├── agents.md
├── AppStore+TeamHelpers.swift
├── AppStore.swift
└── MockData.swift
```

## 文件职责
- `AppStore.swift`: 应用状态容器与核心领域操作入口（主流程方法）。
- `AppStore+TeamHelpers.swift`: 团队关联维护、头像落盘与权限判定扩展方法。
- `MockData.swift`: 本地 Mock 数据与初始化脚本（含消息样本）。

## 开发规范
- 对外只暴露数据操作接口，避免视图层访问内部细节。

## 变更日志
- 2026-02-20: 发布前收敛会话与种子策略，Release 默认关闭本地 Mock 种子并禁用 debug-token 自动建会话。
- 2026-02-16: 新增 `AppStore+TeamHelpers.swift`，拆分团队辅助逻辑并将 `AppStore.swift` 控制到 800 行内。
- 2026-02-16: `updateCurrentUserProfile` 增加头像写入能力，支持用户头像文件落盘与快照同步。
- 2026-02-08: 新增入队申请状态存储与审批接口，补齐消息页 Mock 数据。
- 2026-02-04: 初始化数据层索引。
- 2026-02-04: 增加队伍创建/加入/移交等领域操作。

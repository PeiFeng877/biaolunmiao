# BianLunMiaoUITests/agents.md - UI 测试索引

[PROTOCOL]: 变更时更新此头部，然后检查 agents.md

**版本**: v2.6
**日期**: 2026-03-22

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
├── BianLunMiaoProdDataUITests.swift
├── BianLunMiaoDeviceSpecialUITests.swift
├── BianLunMiaoSpecializedUITests.swift
└── BianLunMiaoUITestsLaunchTests.swift
```

## 文件职责
- `BianLunMiaoUITestSupport.swift`: UI 测试公共启动、等待、lane 约束与诊断支持。
- `BianLunMiaoSmokeLocalUITests.swift`: 默认 `smoke-local` 冒烟用例。
- `BianLunMiaoFunctionalUITests.swift`: `full-local` 长链路功能回归。
- `BianLunMiaoLocalRemoteUITests.swift`: 本机后端联调用例。
- `BianLunMiaoProdDataUITests.swift`: `FC` 默认域名真机数据专项用例，覆盖队伍/赛事/场次 CRUD 与日历同步。
- `BianLunMiaoDeviceSpecialUITests.swift`: 真机专项用例，覆盖登录入口可达性与手机号真机登录闭环。
- `BianLunMiaoSpecializedUITests.swift`: App Store 截图与启动性能专项。
- `BianLunMiaoUITestsLaunchTests.swift`: Launch screenshot 专项。

## 变更日志
- 2026-03-22: `local-remote` lane 改为通过 UI 真正创建队伍后再覆盖赛事、场次、日程、消息、个人链路；`device-special` 为手机号错误态补充稳定断言锚点。
- 2026-03-22: `device-special` lane 补充手机号登录真机闭环用例，覆盖手机号入口、验证码登录、首登资料完善与主 Tab 落点。
- 2026-03-22: UI 自动化 lane 收口为 smoke/full-local/local-remote/prod-data/device-special/specialized，移除 `stg` 作为现行执行路径。
- 2026-03-21: `prod-data` lane 补充日历同步真机用例，正式服预演范围扩展到队伍/赛事/场次 CRUD + 日历同步。
- 2026-03-21: 新增 `prod-data` lane 与 `BianLunMiaoProdDataUITests.swift`，用于正式服默认域名真机 CRUD 预演。
- 2026-03-19: UI 自动化按 lane 拆分为 smoke/full-local/local-remote/stg-smoke/device-special/specialized，移除单文件大杂烩入口。
- 2026-02-08: 初始化 UI 测试索引，补齐 L2 文档层。

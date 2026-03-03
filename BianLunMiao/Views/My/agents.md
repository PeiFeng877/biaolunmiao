# BianLunMiao/Views/My/agents.md - 我的页面索引

[PROTOCOL]: 变更时更新此头部，然后检查 agents.md

**版本**: v1.6
**日期**: 2026-03-03

## 模块职责
- 定位: 我的 Tab 页面组合层，承载资料卡、比赛记录与更多路由。
- 边界: 仅负责 UI 组合，不直接处理业务状态。

## 目录结构
```
./BianLunMiao/Views/My
├── agents.md
├── MyHubView.swift
├── ProfileMoreView.swift
└── ProfileSettingsView.swift
```

## 文件职责
- `MyHubView.swift`: 我的 Tab 根页面，使用统一 `AppTopBar`，承接“更多/编辑资料”动作。
- `ProfileSettingsView.swift`: 个人资料卡与已完成比赛时间轴页面。
- `ProfileMoreView.swift`: 应用信息、协议隐私与退出登录统一收纳页面。

## 变更日志
- 2026-03-03: `ProfileMoreView` 新增退出登录入口与确认弹窗，接入 `AppStore.signOut()`。
- 2026-02-17: 修复编辑资料弹窗左上角“取消”被压缩成省略号的问题；取消/保存改为原生导航栏文本按钮并保留统一配色。
- 2026-02-16: 编辑资料弹窗工具栏改为 `cancellationAction/confirmationAction`，确保取消与保存按钮同时显示；移除头像字段 helper 文案。
- 2026-02-16: 编辑资料浮窗移除正文重复标题；新增头像编辑（相册上传）能力；取消/保存按钮上移至顶部栏并统一文本样式。
- 2026-02-16: 我的页改为左标题 + 右侧双图标顶栏；新增 `ProfileMoreView`；资料页新增完赛时间轴并移除原“应用信息/协议与隐私”分段。
- 2026-02-15: `MyHubView` 移除消息分段与详情路由，简化为设置平铺容器。
- 2026-02-13: 初始化我的页面子模块，承载消息并入与设置基础设施入口。

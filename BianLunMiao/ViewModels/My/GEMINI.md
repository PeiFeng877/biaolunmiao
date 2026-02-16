# BianLunMiao/ViewModels/My/GEMINI.md - 我的视图模型索引

[PROTOCOL]: 变更时更新此头部，然后检查 GEMINI.md

**版本**: v1.2
**日期**: 2026-02-16

## 模块职责
- 定位: 我的设置模块视图状态管理。
- 边界: 聚合 `AppStore` 用户与比赛数据，不承载 UI 结构。

## 目录结构
```
./BianLunMiao/ViewModels/My
├── GEMINI.md
└── ProfileSettingsViewModel.swift
```

## 文件职责
- `ProfileSettingsViewModel.swift`: 资料编辑、协议弹层、版本展示与“我的已完成比赛”时间轴数据聚合。

## 变更日志
- 2026-02-16: 资料编辑新增头像草稿状态与取消回滚逻辑；`saveProfile` 支持同时提交昵称与头像更新。
- 2026-02-16: 增加 `finishedMatches` 及赛果/对阵/赛事名称格式化方法，支撑我的页时间轴展示。
- 2026-02-13: 初始化我的视图模型子模块，新增资料编辑状态管理。

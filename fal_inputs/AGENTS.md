# fal_inputs/AGENTS.md - 设计输入样本索引

[PROTOCOL]: 变更时更新此头部，然后检查 AGENTS.md

**版本**: v1.0
**日期**: 2026-02-08

## 模块职责
- 定位: 设计稿/页面生成相关的输入 JSON 样本集合。
- 边界: 仅存放输入样本，不存放业务代码。

## 目录结构
```
./fal_inputs
├── AGENTS.md
├── team_page_duolingo_refresh.json
└── team_page_high_fi.json
```

## 文件职责
- `team_page_high_fi.json`: 队伍页面高保真生成输入。
- `team_page_duolingo_refresh.json`: 队伍页面风格刷新输入。

## 变更日志
- 2026-02-08: 初始化输入样本索引，纳入全局地图。

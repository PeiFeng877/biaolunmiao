# BianLunMiao/DesignSystem/GEMINI.md - 设计系统模块

[PROTOCOL]: 变更时更新此头部，然后检查 GEMINI.md

**版本**: v1.11
**日期**: 2026-02-17

## 模块职责
- 定位: 统一承载颜色、字体、间距、组件样式等设计系统规范。
- 边界: 不包含业务逻辑，仅提供 UI 复用能力。

## 目录结构
```
./BianLunMiao/DesignSystem
├── GEMINI.md
├── README.md
├── ComponentsActions.swift
├── ComponentsButtonAPI.swift
├── ComponentsCore.swift
├── ComponentsFeedback.swift
├── ComponentsForm.swift
├── Theme.swift
```

## 文件职责
- `README.md`: 设计理念、颜色字体定义、组件职责与使用规范的可读文档入口。
- `Theme.swift`: 颜色、字体、间距、圆角、阴影等基础令牌。
- `ComponentsCore.swift`: 背景、顶栏、卡片、头像、标签等核心展示组件。
- `ComponentsForm.swift`: 输入控件与表单容器组件。
- `ComponentsActions.swift`: 按钮样式与空状态反馈组件。
- `ComponentsButtonAPI.swift`: 业务层按钮统一入口（AppButton/AppIconButton/AppRowTapButton/AppMenuAction）。
- `ComponentsFeedback.swift`: 业务层提示统一入口（appToast/appAlert/appConfirmationDialog/appSheet）。

## 变更日志
- 2026-02-17: `AppToolbarTextButtonStyle` 增加单行与固定尺寸约束，避免导航栏工具文字按钮被压缩成省略号。
- 2026-02-13: `AppTopBarStyle` 新增 `schedule`，`AppTopBar` 新增可选隐藏新增按钮能力。
- 2026-02-08: 新增 `ComponentsButtonAPI.swift` 与 `ComponentsFeedback.swift`，建立按钮/提示统一 API。
- 2026-02-07: 将原 `Components.swift` 拆分为 Core/Form/Actions 三文件，消除超大文件坏味道。
- 2026-02-07: 升级 Neo-Brutal Neon v2.0，重写 token 与组件视觉参数，并更新 `README.md` 规范。
- 2026-02-07: 新增 `README.md`，补齐设计系统可读语义文档。
- 2026-02-07: 目录从 `Design` 重命名为 `DesignSystem`，统一独立管理入口。
- 2026-02-04: 规范化头部信息并更新索引。
- 2026-02-04: 增加顶部栏与队伍头像组件。
- 2026-02-04: 统一主题色与图标字号规范。
- 2026-02-04: 增加深浅模式动态颜色与输入控件规范。

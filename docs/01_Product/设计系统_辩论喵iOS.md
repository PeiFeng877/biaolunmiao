# 辩论喵 iOS 设计系统 (v1.3, Brand-Uniform + Dark Mode)

[PROTOCOL]: 变更时更新此头部，然后检查 agents.md

**版本**: v1.3
**日期**: 2026-02-04
**状态**: 颜色令牌已对齐，组件规范已定义（待落地）

---

## 0. 设计目标
- 统一品牌绿与深色图标体系，避免页面之间的“风格漂移”。
- 同时支持 Light / Dark，确保文字对比度稳定。
- 不追求复杂装饰，靠一致的 Token 与组件建立识别度。
- 组件先于页面，页面只能组合组件，不得发明新风格。

---

## 1. Design Tokens（必须使用，禁止硬编码）

### 1.1 Colors（语义色，支持深浅模式）

**Brand**
| Token | Light | Dark | 用途 |
| --- | --- | --- | --- |
| `brand/primary` | `#7EEA00` | `#7EEA00` | 主强调、按钮、关键交互 |
| `brand/primary-strong` | `#6AD800` | `#6AD800` | 强调/高对比元素 |
| `brand/primary-soft` | `#CFF5A6` | `#2E3D16` | 弱强调、背景小块 |
| `brand/icon-on-primary` | `#171715` | `#171715` | 绿色底上的图标/标题 |

**Neutrals**
| Token | Light | Dark | 用途 |
| --- | --- | --- | --- |
| `bg/background` | `#F6F6F0` | `#14130F` | 全局背景 |
| `bg/surface` | `#FFFFFF` | `#1C1B16` | 卡片/面板 |
| `border/outline` | `#E6E6DE` | `#2C2B24` | 分割线/边框 |
| `text/primary` | `#1F1F1C` | `#F4F3EC` | 主文本 |
| `text/secondary` | `#5C5C54` | `#C2C0B6` | 次级文本 |
| `text/muted` | `#8C8C82` | `#9A978E` | 弱提示/说明 |
| `text/on-dark` | `#FFFFFF` | `#FFFFFF` | 深色背景上的文字 |

**Semantic**
| Token | Light | Dark | 用途 |
| --- | --- | --- | --- |
| `state/info` | `#1CB0F6` | `#1CB0F6` | 提示/链接 |
| `state/reward` | `#FFB100` | `#FFB100` | 奖励/徽章 |
| `state/danger` | `#FF7878` | `#FF7878` | 危险/删除 |

**Avatar Palette（仅用于头像占位）**
- `#F2C6A0` / `#CFE0C3` / `#BFD7EA` / `#E3C7E8`

**颜色规则（强制）**
1. 背景统一用 `bg/background`，卡片统一用 `bg/surface`。
2. 文本默认 `text/primary`，提示类文本 `text/muted`。
3. 禁止出现浅色文字叠在浅色背景（对比度不足即错误）。
4. 任何颜色必须来自 Token，禁止随手写 `Color(...)`。

### 1.2 Typography
- 标题层级统一为：`hero` / `title` / `section` / `body` / `caption`。
- 图标大小统一使用 `iconSmall / iconMedium / icon`。

### 1.3 Spacing
- 基准单位: 4
- 梯度: 4 / 8 / 12 / 16 / 24 / 32

### 1.4 Radius & Shadow
- Radius: `s=10`, `m=14`, `l=16`
- Shadow: 仅用于卡片/浮层，使用 `shadow/subtle`

---

## 2. 组件规范（必须复用）

### 2.0 组件清单（单一真相源）
- 基础容器: Card, Surface, Section
- 表单: FormField, TextField, TextArea, SearchBar, IconField
- 选择器: AvatarPicker（Preset / Image）
- 导航: TopBar
- 操作: PrimaryButton, SecondaryButton, GhostButton, DangerButton
- 反馈: EmptyState, Tag, Badge

### 2.1 Top Bar
- 左侧产品爪子 Logo
- 中间页面标题
- 右侧“+”按钮
- 背景色：`brand/primary-strong`，图标/标题色：`brand/icon-on-primary`

### 2.2 Card（卡片）
- 基础样式: `bg/surface` + `border/outline` + `radius/l` + `shadow/subtle`
- 变体
  - Standard: 默认卡片（列表、模块容器）
  - Interactive: 仅在可点击场景，增加轻微阴影，不改变颜色
  - Emphasis: 仅用于 Featured 等重点模块，允许渐变背景
- 只允许一层容器，不要卡片套卡片
- 卡片内部分区用 `Divider` 或 `Section` 间距，不新增第二层 Card

### 2.3 FormField（表单字段：统一结构）
- 结构固定为: Label + Input + HelperRow
- HelperRow 用于提示、错误、字数统计，统一在字段内部
- 字数统计必须位于 HelperRow 右侧，格式 `current/limit`
- 错误信息优先级最高，颜色 `state/danger`
- Input 区域样式
  - 背景: `bg/background`
  - 边框: `border/outline`
  - 圆角: `radius/s`
  - 文字: `text/primary`
  - Placeholder: `text/muted`

### 2.4 Inputs（输入控件）
- TextField: 单行输入，走 FormField 结构
- TextArea: 多行输入，走 FormField 结构，最小高度 90
- SearchBar: 左图标 + 输入，使用同一 Input 样式
- IconField: 左图标 + 输入，供赛程设定等场景复用
- 禁止把字数统计放在字段外部
- 禁止在输入控件外再包一层“伪卡片”

### 2.5 AvatarPicker（头像选择）
- Preset 模式（MVP 1.0）
  - 3 列网格，单元 60x60
  - 选中态外圈 2px，颜色 `brand/primary`
  - AvatarBadge 负责图标与底色
- Image 模式（若允许上传）
  - 入口为网格内“上传”单元
  - 选择图片后裁剪为圆形，尺寸与 Preset 一致
  - 空状态展示 `photo` 图标与提示文案
- 两种模式不可同时堆叠，只能二选一或用 Tab 切换

### 2.6 List（列表）
- 列表卡片之间统一 `spacing = 12`
- 列表内卡片统一使用 Card Standard

### 2.7 Buttons
- Primary: `bg=brand/primary`，文字 `text/on-dark`
- Secondary: 透明底 + `brand/primary` 边框
- Danger: `state/danger`

### 2.8 Tag / Badge
- Tag：浅底 + 边框（弱强调）
- Badge：`state/reward`

### 2.9 Empty State
- 必须给下一步动作按钮（Primary）
- 图标使用系统图标，颜色 `brand/primary`

---

## 3. 开发约束（强制）
1. 所有字体、字号、颜色必须调用设计 Token。
2. 任何 TextField / TextEditor 必须设置文字与 Placeholder 的 Token。
3. 页面内最多一个主色强调区（避免“到处都在抢戏”）。
4. 组件样式必须复用设计系统，禁止临时魔改。
5. 字数统计属于 FormField，不得放在字段外部。
6. 新增组件前先补文档，再做实现。

---

## 4. 变更日志
- 2026-02-04: 增加组件清单与 FormField/AvatarPicker 规范，明确卡片变体与约束。

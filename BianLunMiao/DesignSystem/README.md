# BianLunMiao Design System v2.0 (Neo-Brutal Neon)

[PROTOCOL]: 变更时更新此头部，然后检查 GEMINI.md

**版本**: v2.0  
**日期**: 2026-02-07  
**定位**: 这是设计师与开发共同维护的语义设计基线，代码实现以 `Theme.swift` 与 `Components*.swift` 为唯一执行面。

## 1. 设计理念
- 物理感优先: 所有交互容器必须有硬边框与硬阴影，点击产生物理位移。
- 电子清新: 以 Fluorescent Green 驱动焦点，用黑/绿高对比建立视觉秩序。
- 视觉呼吸: 通过更大的圆角与更宽留白，平衡黑边框的压迫感。
- 语义稳定性: 保留语义命名体系，但参数完全切换到 Neo-Brutal Neon。

## 2. Token 系统

### 2.1 颜色系统 (The Neon Palette)

| 分类 | Token | Light (Neo) | Dark (Midnight) | 用途 |
| --- | --- | --- | --- | --- |
| 中性色 | `AppColor.background` | `#F4FFEB` | `#080808` | 全局背景 |
| 中性色 | `AppColor.surface` | `#FFFFFF` | `#121212` | 容器背景 |
| 描边 | `AppColor.stroke` | `#000000` | `#33FF00` | 所有容器主描边 |
| 品牌 | `AppColor.primary` | `#CCFF00` | `#CCFF00` | 主操作色 |
| 品牌 | `AppColor.primaryStrong` | `#A3CC00` | `#A3CC00` | 按下态/强调态 |
| 品牌 | `AppColor.primarySoft` | `#E6FFAD` | `#1A2600` | 聚焦背景/弱强调 |
| 文本 | `AppColor.textPrimary` | `#000000` | `#FFFFFF` | 主文本 |
| 文本 | `AppColor.textSecondary` | `#4D4D4D` | `#999999` | 次级文本 |
| 语义 | `AppColor.reward` | `#FFDE00` | `#FFDE00` | 奖励/徽章 |
| 语义 | `AppColor.danger` | `#FF3B30` | `#FF3B30` | 危险/警示 |

说明:
- 深色模式描边默认反转为荧光绿。
- 兼容层 `event*` token 继续保留，映射到 v2.0 新参数。

### 2.2 字体系统 (Typography Evolution)
- `AppFont.hero()`: 32 / Heavy / Rounded
- `AppFont.title()`: 24 / Black / Rounded
- `AppFont.section()`: 18 / Bold / Rounded
- `AppFont.body()`: 16 / Medium / Rounded
- `AppFont.caption()`: 12 / Bold / Monospaced
- Tracking: 全局推荐 `AppFont.tracking = -0.2`（SwiftUI 点值近似 -0.02em 语义）

### 2.3 结构参数 (Structural Specs)
- Spacing: 4px 递进；新增 `AppSpacing.inset = 20` 作为页面标准边距。
- Radius:
  - `AppRadius.s = 12`
  - `AppRadius.m = 24`（Card/Input）
  - `AppRadius.l = 32`（Sheet/Dock）
- Shadow:
  - `AppShadow.standard = (x:4, y:4, blur:0, #000)`
  - `AppShadow.accent = (x:4, y:4, blur:0, AppColor.primary)`

## 3. 组件系统重塑 (Components 2.0)

### 3.1 布局与容器
- `AppBackground`: 低对比噪点纹理背景。
- `AppCard`:
  - Standard: Surface + 1.5pt 描边 + 硬阴影。
  - Interactive: 按下后阴影归零，容器 offset(4,4)。
  - Emphasis: 描边强制主色。
  - 支持 `isBreathing` 呼吸边框（黑 -> 绿 -> 黑，0.8s）。

### 3.2 导航与顶部栏
- `AppTopBar`: 透明色块被移除，改为悬浮胶囊容器。
- `AppTopBarIcon` / `AppTopBarButton`: 黑底圆形 + 荧光绿图标 + 1.5pt 描边。
- `AppDetailTopBar`: 详情页专用顶部栏，左右动作按钮同构，避免系统导航栏样式漂移。

### 3.3 表单输入
- `AppTextField` / `AppIconField` / `AppTextEditor`:
  - 默认 2px 描边 + 白/深色容器底。
  - 聚焦后切换 `primarySoft` 背景并启用主色硬阴影。
- `AppSearchBar`: 胶囊形态 + 加粗线性搜索图标。

### 3.4 状态与操作
- `AppPrimaryButtonStyle`: 绿底 + 黑边 + 黑字 + 重字重 + 硬阴影。
- `AppEmptyState`: 黑线轮廓 + 主色局部填充 + 放大标题排版。

### 3.5 业务按钮 API
- `AppButton`: 统一文本按钮入口，支持 `primary/secondary/compactSecondary/ghost/toolbarText`。
- `AppIconButton`: 统一图标按钮入口，用于顶部栏图标动作。
- `AppRowTapButton`: 行级点击入口，替代业务层裸 `Button + .buttonStyle(.plain)`。
- `AppMenuAction`: 菜单与确认动作入口，替代业务层对话框内裸 `Button`。

### 3.6 反馈 API
- `appToast` + `AppToastPayload`: 非阻断反馈默认方案。
- `appAlert`: 系统级权限/阻断提示入口。
- `appConfirmationDialog`: 不可逆操作确认入口。
- `appSheet`: 输入型流程弹层入口。

### 3.5 业务子组件
- `TeamAvatarBadge`: 内层 2px 白描边 + 外层 1.5px 主描边。
- `AppAvatarStack`: 新增堆叠组件，默认重叠 `-10`，最新项在最上层。

## 4. 交互语义
- 所有 DesignSystem 按钮使用中等冲击触感反馈。
- `AppCard(style: .interactive)` 内置物理按压位移与反馈。
- 全局位移动效采用弹性曲线（Spring，阻尼比接近 0.6 的体感）。

## 5. 使用规则
- 边框第一原则: 除纯文本外，交互容器必须有描边。
- 阴影非零原则: 禁止使用 blur > 0 的阴影。
- 装饰禁用: 禁止渐变、发光模糊、无语义透明装饰。
- 深色模式对齐: 描边色优先反转为荧光绿，保持黑夜霓虹识别。
- 业务层禁止裸 `Button` 与原生 `.alert/.sheet/.confirmationDialog`，必须通过 DesignSystem API 调用。
- 详情页顶部禁止混用系统导航按钮与文本工具栏按钮，必须使用 `AppDetailTopBar`。

## 6. Roadmap
- 字体: 计划引入 Plus Jakarta Sans 替换系统字体。
- 图标: 统一到 Bold 单线风格，清理遗留阴影图标。
- 性能: 对高频列表组件补齐 `shadowPath` 优化以降低离屏渲染成本。

## 7. 快速索引
- Token: `BianLunMiao/DesignSystem/Theme.swift`
- Components Core: `BianLunMiao/DesignSystem/ComponentsCore.swift`
- Components Form: `BianLunMiao/DesignSystem/ComponentsForm.swift`
- Components Actions: `BianLunMiao/DesignSystem/ComponentsActions.swift`
- Components Button API: `BianLunMiao/DesignSystem/ComponentsButtonAPI.swift`
- Components Feedback API: `BianLunMiao/DesignSystem/ComponentsFeedback.swift`
- Module Map: `BianLunMiao/DesignSystem/GEMINI.md`

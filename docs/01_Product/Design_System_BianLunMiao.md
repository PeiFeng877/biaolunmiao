# 辩论喵 iOS 设计系统 (v1.0, Duolingo-Style)

**版本**: v1.0
**日期**: 2026-02-04
**状态**: 可交付（含令牌、组件规则、文案基调、资源清单）

**Duolingo 规范来源 (Source of truth)**
- https://design.duolingo.com/identity/color
- https://design.duolingo.com/identity/typography
- https://design.duolingo.com/illustration/shape-language
- https://design.duolingo.com/writing/voice
- https://design.duolingo.com/writing/tone
- https://design.duolingo.com/writing/style

---

## 0. 设计结论（先把方向钉死）

**我们要的不是“卡片化 UI”，而是“Duolingo 的轻快扁平 + 强语义色彩 + 友好圆角”。**

### 0.1 视觉目标
- 年轻、活泼、自由、偏酷（利落，不软糯）
- 社交社区氛围（鼓励互动和参与）
- 游戏化反馈（奖励/进度/成就），但不堆装饰

### 0.2 三条铁律（防丑）
1. **单主色**: 只允许一个品牌主色（绿），其余颜色只能做语义用途。
2. **单标题**: 每个页面只允许一个“页面标题”（导航标题/大标题二选一）。禁止“大标题 + 卡片小标题”的重复结构。
3. **单容器**: 一个信息块最多一层容器（不要卡片套卡片；不要线框套线框）。

---

## 1. 品牌角色：辩论喵（狸花猫）

**定位**: 情绪锚点 + 反馈载体（不拟人，不说教）。

**形象关键词**: 真实猫比例 / 活泼 / 傲娇 / 自信 / 轻嫌弃

**上屏规则**
- 只在“空状态 / 完成反馈 / 成就解锁 / 新手引导”出现。
- 内容密集页（列表/表单）默认不出现，避免干扰效率。

---

## 2. Tokens（可直接实现的设计令牌）

> 参考 Duolingo 的颜色层级：Feather Green 为核心品牌色，Snow 为主背景，Eel 为常用正文色。来源: https://design.duolingo.com/identity/color

### 2.1 Colors（语义色，禁止随意混用）

**Brand**
| Token | HEX | 用途 |
| --- | --- | --- |
| `brand/primary` | `#58CC02` | 主 CTA、主交互、主强调（Feather Green） |
| `brand/primary-strong` | `#89E219` | 更亮的绿（高亮、强调、插画点缀） |
| `brand/secondary-blue` | `#1CB0F6` | 信息/链接（仅小面积） |

**Reward / Attention**
| Token | HEX | 用途 |
| --- | --- | --- |
| `reward/orange` | `#FFB100` | 奖励、徽章、进度里程碑（仅语义用途） |
| `state/error` | `#FF7878` | 错误、危险操作 |
| `state/success` | `#58CC02` | 成功（与主色一致，保持品牌统一） |

**Neutrals**
| Token | HEX | 用途 |
| --- | --- | --- |
| `bg/snow` | `#FFFFFF` | 主背景（Snow） |
| `bg/polar` | `#F7F7F7` | 次背景/浅底 | 
| `border/swan` | `#E5E5E5` | 分割线/边框 | 
| `text/eel` | `#4B4B4B` | 正文主色（Eel） |
| `text/wolf` | `#777777` | 次级文本 |
| `text/hare` | `#AFAFAF` | 弱提示 |

**配色规则（必须遵守）**
1. 页面 80% 以上区域使用 `bg/snow` + `text/eel`。
2. `brand/primary` 只给“可点击的主要动作”。
3. `reward/orange` 只给奖励与里程碑，不参与常规按钮。
4. 禁止大面积渐变；渐变只允许用于“奖励/成就”且面积 < 15%。

### 2.2 Typography（字体与层级）

> Duolingo 品牌字体为 DIN Next Rounded / Feather Bold，缺失时可用 Nunito 作为替代。来源: https://design.duolingo.com/identity/typography

**iOS 落地建议**
- 设计目标字体: `Nunito`（更接近 Duolingo 的圆润与友好）
- 工程 fallback: `.system(.rounded)`（先跑通，后续再引入字体资源）

**字号层级（精简版）**
| Level | Size | Weight | Line height | 用途 |
| --- | ---: | --- | ---: | --- |
| `title` | 24 | Bold | 30 | 页面标题（仅一处） |
| `section` | 18 | Semibold | 24 | 区块标题 |
| `body` | 15 | Regular | 22 | 正文 |
| `caption` | 12 | Regular | 18 | 说明/次要信息 |

**排版规则**
- 标题不要两层堆叠；需要副标题时，副标题必须是 `caption` 且不放进卡片。

### 2.3 Spacing（间距）
- 基准单位: 4
- 建议梯度: 4 / 8 / 12 / 16 / 24 / 32

### 2.4 Radius & Elevation（圆角与层级）

**圆角**
- `radius/s`: 10（输入框、标签）
- `radius/m`: 14（按钮）
- `radius/l`: 16（面板/底部 sheet）

**阴影（克制）**
- 默认不使用阴影，用 `border/swan` 分割。
- 仅在“浮层/可拖拽面板/底部 sheet”使用轻阴影。

### 2.5 Motion（动效）

> 先不做插画与动画资源，但 UI 必须预留节奏。后续再补。

- Press: 0.96 缩放，120ms
- Success: 轻弹回弹，240-360ms
- Reward: 420-600ms（仅成就/升级）

---

## 3. 组件规范（用法 + 反用法）

### 3.1 页面结构（最重要）

**标准页面骨架**
1. 导航标题（系统导航栏）
2. 内容区：列表或表单（保持平面化）
3. 主要 CTA：固定在底部或放在右上角（但不要两者同时强强调）

**禁止模式**
- 顶部 hero 卡片 + 下面 section header + 下面卡片列表（重复包装）
- 卡片里再套输入卡片（表单双层容器）

### 3.2 列表（List/Feed）
- 默认用“平面列表 + 分割线”，不要给每一行都包大卡片。
- 行内可用小面积圆形图标底（`brand/primary` 10-15% 透明度）。
- 角标/状态用 Tag（胶囊），不要用卡片。

### 3.3 卡片（Panel）
**什么时候用**
- 一段信息需要“自成块”并与背景区分（如：统计面板、空状态块、提示块）。

**怎么用**
- 背景: `bg/polar`
- 边框: `border/swan` 1px
- 内边距: 16
- 一屏不超过 3 个大卡片

### 3.4 按钮（Button）
- Primary: 纯色 `brand/primary`（不使用渐变）
- Secondary: 透明底 + `brand/primary` 边框
- Danger: `state/error`

交互状态
- Pressed: 0.96 缩放 + 轻微变暗
- Disabled: 降低对比度，不改变布局

### 3.5 输入框（Input）
- 背景: `bg/snow`
- 边框: `border/swan`
- Focus: `brand/primary`
- 表单页面：推荐“分组面板 1 层 + 输入框原生样式”，禁止“输入框再包卡片”。

### 3.6 标签/徽章（Tag/Badge）
- Tag（状态）: 边框或浅底，不抢主色
- Badge（奖励）: `reward/orange`，可加小 icon，但面积克制

### 3.7 空状态（Empty）
- 第一版用系统图标占位；后续替换为“辩论喵插画”。
- 空状态必须给“下一步动作”按钮（Primary）。

---

## 4. 形状语言（Shape Language → UI 映射）

> 参考 Duolingo 的 shape language：强调圆润、形状重复、空间中的对象与浮动装饰的节制使用。来源: https://design.duolingo.com/illustration/shape-language

**UI 映射规则**
1. 统一圆角梯度（10/14/16），不要一屏出现 5 种圆角。
2. 图标底座统一为圆形或胶囊（形状重复）。
3. “装饰背景”（模糊色块）可用，但必须弱化到 5-10% 透明度，不抢信息。

---

## 5. 文案系统（Voice/Tone）

> Duolingo Voice qualities: Expressive / Playful / Embracing / Worldly。来源: https://design.duolingo.com/writing/voice

**辩论喵的文案人格（中文落地）**
- 表达: 简短、有动作感（"开战"、"集结"、"上场"）
- 有趣: 偶尔一句轻俏皮，但不装嫩
- 包容: 错误与失败不羞辱用户
- 见过世面: 用词干净，不幼稚

**Do / Don’t**
- Do: “已创建队伍，去邀请队友开战吧。”
- Do: “差一点点。下一场更稳。”
- Don’t: “你失败了！”（羞辱）
- Don’t: “请前往系统设置页面开启权限以进行日程同步操作。”（官腔）

---

## 6. 资源清单（先低成本，再升级）

### 6.1 P0（现在就该有，纯代码可替代）
1. 颜色令牌与主题（无需插画）
2. Icon 规范（SF Symbols 选型）
3. 页面结构规则（避免双标题/卡片嵌套）

### 6.2 P1（确认方向 OK 后补）
1. 辩论喵静态插画: 空状态 6 张
2. 辩论喵表情: 8 个（开心/傲娇/嫌弃/惊讶/鼓励/得意/紧张/庆祝）
3. 成就徽章: 12 个（可先用纯形状图标）

### 6.3 P2（最后再做，成本最高）
1. 成就解锁动效（Lottie/SwiftUI 动画皆可）
2. 轻待机动效（尾巴/耳朵）
3. 列表进入动效与奖励粒子

---

## 7. 迁移检查清单（每个页面都要过一遍）

1. 是否只保留一个页面标题？
2. 是否存在卡片套卡片？（一旦出现，优先删外层）
3. 主 CTA 是否只有一个？（右上角 + 底部二选一）
4. 主色是否只有绿色？其他色是否严格语义化？
5. 文案是否短、动作感强、且不官腔？

---

## 8. 变更日志
- 2026-02-04: v1.0 采用 Duolingo design guidelines 重写（单主色绿 + 单标题 + 单容器），并给出资源分级清单。

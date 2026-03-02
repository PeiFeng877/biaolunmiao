# 跨端视觉与交互同构规范（Android 复刻）

[PROTOCOL]: 变更时更新此头部，然后检查 agents.md

**版本**: v1.0
**日期**: 2026-02-23
**适用范围**: `bianlunmiao-ios` 与 `bianlunmiao-android`

## 1. 目标
1. Android 与 iOS 在视觉语言、交互节奏、信息架构上保持同构，用户感知为同一款 App。
2. 在不改后端契约前提下，仅通过 Android UI 结构重整与设计系统映射实现复刻。

## 2. 视觉 token 映射（iOS -> Android）
| iOS Token | Android Token | 说明 |
| --- | --- | --- |
| `AppColor.background` | `AppColors.Background` | 全局背景 |
| `AppColor.surface` | `AppColors.Surface` | 卡片与容器背景 |
| `AppColor.stroke` | `AppColors.Stroke` | 主描边 |
| `AppColor.primary` | `AppColors.Primary` | 主操作色 |
| `AppColor.primaryStrong` | `AppColors.PrimaryStrong` | 主色强调态 |
| `AppColor.primarySoft` | `AppColors.PrimarySoft` | 弱强调底色 |
| `AppColor.textPrimary` | `AppColors.TextPrimary` | 主文本 |
| `AppColor.textSecondary` | `AppColors.TextSecondary` | 次文本 |
| `AppColor.danger` | `AppColors.Danger` | 危险态 |
| `AppColor.reward` | `AppColors.Reward` | 奖励态 |

## 3. 交互映射
1. 5 Tab 同构：队伍、赛事、日程、消息、我的。
2. 顶部栏同构：标题 + 次动作 + 主动作结构统一。
3. 卡片同构：硬边框 + 高对比 + 按压位移反馈。
4. 弹层同构：创建/加入/新增来源等输入流统一使用底部弹层。
5. 详情页同构：统一 `AppDetailTopBar`，返回路径固定到来源 Tab。

## 4. 组件映射
| iOS 组件 | Android 组件 |
| --- | --- |
| `AppTopBar` | `AppTopBar` |
| `AppDetailTopBar` | `AppDetailTopBar` |
| `AppCard` | `AppCard` |
| `AppButton` | `AppButton` |
| `AppTextField` | `AppTextField` |
| `AppSearchBar` | `AppSearchBar` |
| `AppEmptyState` | `AppEmptyState` |
| `AppToastPayload + appToast` | `AppToastPayload + AppToastHost` |

## 5. 页面映射
1. 队伍：`TeamListView.swift` -> `TeamRootScreen.kt` / `TeamDetailScreen.kt`。
2. 赛事：`TournamentListView.swift` -> `TournamentRootScreen.kt` / `TournamentDetailScreen.kt`。
3. 日程：`ScheduleView.swift` -> `ScheduleRootScreen.kt` / `ScheduleDayDetailScreen.kt`。
4. 消息：`MessageHubView.swift` -> `MessageRootScreen.kt` / `MessageDetailScreen.kt`。
5. 我的：`MyHubView.swift` -> `MyRootScreen.kt` / `ProfileEditScreen.kt` / `ProfileMoreScreen.kt`。

## 6. 同构裁决规则
1. 若 iOS 现状与 PRD 冲突，以 `docs/` 下最新 SSOT 文档为准。
2. Android 保留系统返回手势与系统权限弹窗差异，其余交互优先同构。
3. 同构容差默认：间距 `<= 2dp`，字号 `<= 1sp`，核心动效时长 `<= 30ms`。

## 变更日志
- 2026-02-23: 新增 Android 复刻场景下的跨端视觉与交互同构规范。

# 跨端视觉与交互同构规范（Flutter 迁移版）

[PROTOCOL]: 变更时更新此头部，然后检查 agents.md

**版本**: v1.0
**日期**: 2026-03-05
**状态**: 历史归档（2026-03-14 起退出现行 SSOT）

## 1. 目标
1. Flutter 客户端在信息架构、交互节奏、视觉语义上与 iOS 保持同构。
2. 不改变既有产品语义与接口契约，仅替换端内实现技术栈。

## 2. 同构原则
1. 业务规则、接口字段、错误语义以根目录 `docs/03_接口与数据契约/` 为准。
2. 允许平台原生差异（系统返回手势、系统权限弹窗），其余交互保持一致。
3. 同构容差默认：间距 `<= 2dp`，字号 `<= 1sp`，关键动效时长偏差 `<= 30ms`。

## 3. 视觉 token 映射（iOS -> Flutter）
| iOS Token | Flutter Token（建议） | 说明 |
| --- | --- | --- |
| `AppColor.background` | `AppColors.background` | 全局背景 |
| `AppColor.surface` | `AppColors.surface` | 卡片与容器背景 |
| `AppColor.stroke` | `AppColors.stroke` | 主描边 |
| `AppColor.primary` | `AppColors.primary` | 主操作色 |
| `AppColor.primaryStrong` | `AppColors.primaryStrong` | 主色强调态 |
| `AppColor.primarySoft` | `AppColors.primarySoft` | 弱强调底色 |
| `AppColor.textPrimary` | `AppColors.textPrimary` | 主文本 |
| `AppColor.textSecondary` | `AppColors.textSecondary` | 次文本 |
| `AppColor.danger` | `AppColors.danger` | 危险态 |
| `AppColor.reward` | `AppColors.reward` | 奖励态 |

## 4. 交互与组件映射
1. 5 Tab 同构：队伍、赛事、日程、消息、我的。
2. 顶部栏同构：标题 + 次动作 + 主动作结构一致。
3. 弹层同构：创建/加入/编辑流程优先使用底部弹层。
4. 卡片同构：硬边框 + 高对比 + 按压反馈。
5. 组件映射以语义为准，禁止仅为“写起来方便”改动交互路径。

## 5. 页面映射（语义）
1. 队伍：队伍列表、队伍详情、创建/加入流程。
2. 赛事：赛事列表、赛事详情、场次管理、赛果录入。
3. 日程：按月/按日查看、来源管理、日历同步。
4. 消息：消息列表、入队请求详情与确认。
5. 我的：资料编辑、更多设置、退出登录。

## 6. 验收规则
1. 同构验收以 `docs/05_历史归档/04_Flutter阶段资料/12_跨端同构验收清单_Flutter.md` 为准。
2. 若 iOS 现状与本文件冲突，以 `docs/01_产品与体验/01_MVP核心规则_PRD.md` 与最新接口契约裁决。

## 变更日志
- 2026-03-14: 迁入历史归档，停止作为现行跨端同构规范执行依据。
- 2026-03-05: 新建 Flutter 迁移版同构规范，替换 Android 阶段遗留规范的现行位置。

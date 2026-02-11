# Feedback Component Spec

[PROTOCOL]: 变更时更新此头部，然后检查 GEMINI.md

**版本**: v1.0
**日期**: 2026-02-08
**范围**: `BianLunMiao/Views` 中所有提示、确认、弹层反馈。

## 1. 组件白名单
- `appToast` + `AppToastPayload`
- `appAlert`
- `appConfirmationDialog`
- `appSheet`

## 2. 禁止项
- 业务层禁止直接调用 `.alert`。
- 业务层禁止直接调用 `.sheet`。
- 业务层禁止直接调用 `.confirmationDialog`。
- 业务层禁止直接调用 `.fullScreenCover`。

## 3. 语义分层
- 非阻断反馈默认 `Toast`。
- 不可逆操作确认使用 `appConfirmationDialog`。
- 输入型流程使用 `appSheet`。
- 权限/系统级提示使用 `appAlert`。

## 4. 当前项目迁移决策
- 转为 Toast: 申请提交、审批结果、日历添加成功、重复添加、功能即将上线。
- 保留 Alert: 日历权限拒绝/受限。
- 保留 ConfirmationDialog: 删除/移交等不可逆操作。
- 保留 Sheet: 创建/编辑/提交表单流程。

## 5. 审计入口
- 生成清单: `swift docs/03_Governance/tools/governance_audit.swift --mode generate`
- 校验一致性: `swift docs/03_Governance/tools/governance_audit.swift --mode check`

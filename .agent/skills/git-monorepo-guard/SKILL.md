---
name: git-monorepo-guard
description: 当在辩论喵单仓内处理 Git 状态检查、提交、合并、推送、发版或仓库清理时使用。约束当前仓库的单一 Git 根、提交范围、自检顺序、推送失败排查与禁止事项。
---

# Git 单仓守卫

[PROTOCOL]: 变更时更新此头部，然后检查 agents.md

**版本**: v1.1
**日期**: 2026-03-20
**适用范围**: `/Users/Icarus/Documents/project 2026/bianlunmiao`

仅在 `/Users/Icarus/Documents/project 2026/bianlunmiao` 内使用此 skill。

## 1. 事实源
- 根规则: [agents.md](../../../../agents.md)
- Git 流程 SSOT: [docs/00_协作治理/02_Git与提交流程规范.md](../../../../docs/00_协作治理/02_Git与提交流程规范.md)
- 单仓边界 SSOT: [docs/00_协作治理/05_一仓协作与目录边界规范.md](../../../../docs/00_协作治理/05_一仓协作与目录边界规范.md)
- 发版流程 SSOT: [docs/04_测试与发布/01_规范/16_单仓发版执行规范.md](../../../../docs/04_测试与发布/01_规范/16_单仓发版执行规范.md)

## 2. 提交或合并前必须做的检查
1. 执行 `pwd`，确认当前位于主仓工作区。
2. 执行 `git rev-parse --show-toplevel`，结果必须等于 `/Users/Icarus/Documents/project 2026/bianlunmiao`。
3. 执行 `git status --short`，确认所有改动都属于同一功能主题或同一治理动作。
4. 若同时改动 `docs/`、`bianlunmiao-ios/`、`bianlunmiao-admin/`、`辩论喵-后端/`，必须在提交说明或交接说明中写清同一业务原因。

## 3. 当前仓库的专属规则
1. 当前仓库只允许一个 Git 根；任何业务子目录都不得保留独立 `.git/`。
2. 提交按功能主题拆分，不按目录名机械拆分；目录只是边界，不是提交理由。
3. 工作区不得残留 `* 2.*` 重复文件、`* 2` 重复目录或 Finder 风格冲突副本。
4. 涉及跨端契约变化时，必须先更新 `docs/03_接口与数据契约/`，再视为实现完成。
5. 只改代码不回写所需文档，不算完成。
6. `bianlunmiao-admin/.next/`、`bianlunmiao-admin/.next.backup.*/`、`bianlunmiao-admin/.vercel/`、`bianlunmiao-admin/next-env.d.ts` 属于本地产物，必须保持为忽略项。

## 4. 合并与清理行为
1. 完成分支并入 `main` 时，优先使用 `git merge --ff-only`。
2. 合并前要先提交本分支应包含的清理动作，不允许带着原因不明的脏工作区合并。
3. 若发现嵌套 `.git/`、重复副本或治理文档过期，应先修复，再发版或合并主干。
4. 未经用户明确许可，不得执行 `git reset --hard`、`git checkout --`、强推等破坏性操作。

## 5. 推送失败排查顺序
1. 先检查认证与读远端能力，再判断是否是代理问题；至少执行 `gh auth status` 或 `ssh -T git@github.com` 之一，并执行 `git ls-remote --heads origin`。
2. 若 `ls-remote` 正常但 `git push` 卡住、超时或被拒收，优先检查远端预接收拒绝、超大对象和本地产物误入历史，不要先下结论说是代理问题。
3. 若怀疑是大对象，先检查未推送提交范围内是否混入构建产物，再决定清理方案。
4. 若需要改写未推送历史来移除误入对象，应先向用户说明影响范围；若涉及已推送历史或强推，必须得到用户明确许可。
5. 当 HTTPS push 行为异常但 SSH 认证正常时，可以切换为 SSH 远端重试；切换前仍要先完成上面的对象与拒收排查。

## 6. 最低验证基线
- iOS 治理检查: `swift bianlunmiao-ios/docs/03_Governance/tools/governance_audit.swift --mode check --root bianlunmiao-ios`
- Admin 基线: `pnpm --dir bianlunmiao-admin lint`
- 后端基线: `make -C 辩论喵-后端 lint`
- iOS 最小 lane: `bash scripts/ios_ui_lane.sh smoke-local`

## 7. 输出要求
- 处理当前仓库的 Git 任务时，结果中必须说明:
  - 当前分支
  - 工作区是否干净
  - Git 根是否正确
  - 文档是否同步
  - 执行了哪些验证，或哪些验证被跳过

## 变更日志
- 2026-03-20: 改写为中文版本，补齐 `[PROTOCOL]`、版本、日期与变更日志。
- 2026-03-20: 新增推送失败排查顺序，要求先排除远端拒收与超大对象，再判断代理因素。
- 2026-03-20: 新增 Web 管理端构建缓存与 `next-env.d.ts` 的忽略约束，避免本地产物再次污染单仓历史。

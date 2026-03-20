---
name: git-monorepo-guard
description: Use when working with Git in the bianlunmiao monorepo, especially before status checks, commits, merges, releases, or repository cleanup. Enforces the repo-specific single-repo root, commit-scope rules, required preflight checks, and no-nested-git policy for /Users/Icarus/Documents/project 2026/bianlunmiao.
---

# Git Monorepo Guard

Use this skill only inside `/Users/Icarus/Documents/project 2026/bianlunmiao`.

## Source of truth
- Root rule: [agents.md](../../../../agents.md)
- Git workflow SSOT: [docs/00_协作治理/02_Git与提交流程规范.md](../../../../docs/00_协作治理/02_Git与提交流程规范.md)
- Monorepo boundary SSOT: [docs/00_协作治理/05_一仓协作与目录边界规范.md](../../../../docs/00_协作治理/05_一仓协作与目录边界规范.md)
- Release flow SSOT: [docs/04_测试与发布/01_规范/16_单仓发版执行规范.md](../../../../docs/04_测试与发布/01_规范/16_单仓发版执行规范.md)

## Required checks before any commit or merge
1. Run `pwd` and confirm you are inside the main workspace.
2. Run `git rev-parse --show-toplevel` and confirm it equals `/Users/Icarus/Documents/project 2026/bianlunmiao`.
3. Run `git status --short` and inspect whether every changed path belongs to the same functional topic.
4. If the change spans `docs/`, `bianlunmiao-ios/`, `bianlunmiao-admin/`, and `辩论喵-后端/`, explain the single business reason in the commit or handoff summary.

## Repo-specific rules
- This repo is single-root only. No business subdirectory may contain its own `.git/`.
- Do not treat different directories as separate commit scopes. Split commits by feature topic, not by module name alone.
- Do not leave `* 2.*` duplicate copies, copied directories, or other Finder-style conflict artifacts in the worktree.
- Cross-end contract changes must update `docs/03_接口与数据契约/` before implementation is considered complete.
- Code-only changes without the required doc updates are not done.

## Merge and cleanup behavior
- Prefer `git merge --ff-only` when landing a completed branch onto `main`.
- Before merging, ensure branch-only cleanup actions are already committed; do not merge with an unexplained dirty worktree.
- If you discover nested `.git/`, duplicate copies, or stale governance docs, fix those before release or mainline merge.
- Never use destructive history rewrites (`git reset --hard`, `git checkout --`, force push) unless the user explicitly asks.

## Validation baseline
- iOS governance: `swift bianlunmiao-ios/docs/03_Governance/tools/governance_audit.swift --mode check --root bianlunmiao-ios`
- Admin baseline: `pnpm --dir bianlunmiao-admin lint`
- Backend baseline: `make -C 辩论喵-后端 lint`
- iOS minimum lane: `bash scripts/ios_ui_lane.sh smoke-local`

## Output expectation
- When assisting with Git work in this repo, always report:
  - current branch
  - whether the worktree is clean
  - whether Git root is correct
  - whether docs are in sync
  - what validation was run or skipped

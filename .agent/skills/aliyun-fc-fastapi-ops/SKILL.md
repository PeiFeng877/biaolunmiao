---
name: aliyun-fc-fastapi-ops
description: 当在辩论喵单仓内需要构建、部署、校验或排查阿里云 FC 上承载的 FastAPI 正式后端时使用。
---

# 阿里云 FC FastAPI 操作

[PROTOCOL]: 变更时更新此头部，然后检查 agents.md

**版本**: v1.0
**日期**: 2026-03-22
**适用范围**: `/Users/Icarus/Documents/project 2026/bianlunmiao`

仅在 `/Users/Icarus/Documents/project 2026/bianlunmiao` 内使用此 skill。

## 1. 目标
1. 收口当前 `FC + FastAPI + RDS PostgreSQL Serverless + OSS` 的后端操作路径。
2. 优先复用仓库内已有脚手架，不再回退到已冻结的 EMAS 过渡方案。
3. 保证部署、烟测、回滚说明都能和当前 SSOT 对齐。

## 2. 事实源
- 架构 SSOT: [docs/02_架构与联调/05_FC单正式环境与本地开发方案.md](../../../../docs/02_架构与联调/05_FC单正式环境与本地开发方案.md)
- 部署流程: [docs/02_架构与联调/04_本地联调与阿里云部署流程.md](../../../../docs/02_架构与联调/04_本地联调与阿里云部署流程.md)
- 发版规范: [docs/04_测试与发布/01_规范/16_单仓发版执行规范.md](../../../../docs/04_测试与发布/01_规范/16_单仓发版执行规范.md)
- 后端入口: [辩论喵-后端/README.md](../../../../辩论喵-后端/README.md)
- 构建脚本: [辩论喵-后端/scripts/build_fc_zip.sh](../../../../辩论喵-后端/scripts/build_fc_zip.sh)
- 部署脚本: [辩论喵-后端/scripts/deploy_fc_zip.sh](../../../../辩论喵-后端/scripts/deploy_fc_zip.sh)
- 数据库脚本: [辩论喵-后端/scripts/create_rds_serverless.sh](../../../../辩论喵-后端/scripts/create_rds_serverless.sh)

## 3. 默认工作流
1. 先在 `辩论喵-后端/` 跑 `make lint` 与 `make test`。
2. 需要构建 FC 产物时，执行 `bash 辩论喵-后端/scripts/build_fc_zip.sh`。
3. 需要发布正式函数时，执行 `bash 辩论喵-后端/scripts/deploy_fc_zip.sh`。
4. 需要准备数据库时，优先使用 `bash 辩论喵-后端/scripts/create_rds_serverless.sh` 和 Alembic 迁移，不新增平行脚本。
5. 发布后至少验证 `GET /healthz`、`POST /api`、Apple 登录、媒体上传和正式默认域名 smoke。

## 4. 凭证与安全
1. 阿里云凭证优先走本机 `aliyun` profile，不把 AK/SK、STS、数据库密码或 OSS 密钥写入仓库。
2. 正式参数统一放本机 `.env.fc.prod.local` 等忽略文件，不要写入示例文件之外的跟踪路径。
3. 未经用户明确许可，不要删除正式函数、覆盖正式环境变量或改写正式数据库。

## 5. 输出要求
1. 说明使用的是本地联调、FC 默认域名还是正式函数更新。
2. 说明是否改动了远端资源，尤其是 FC、RDS、OSS。
3. 给出可复述的验证结果和回滚入口。

## 变更日志
- 2026-03-22: 初始化 FC FastAPI 本地 skill，替代已冻结的 EMAS 过渡期 skill。

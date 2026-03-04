# SAE Secret 注入阻塞遗留问题

[PROTOCOL]: 变更时更新此头部，然后检查 agents.md

**版本**: v1.0
**日期**: 2026-03-04

## 1. 问题摘要
- 目标：将生产环境 OSS signer 凭证从 SAE 明文环境变量迁移到 SAE `Opaque Secret`。
- 现状：阿里云 CLI / SAE OpenAPI 在创建业务 `Opaque Secret` 时持续返回服务端错误，当前未完成 Secret 化。
- 当前兜底：生产 OSS 上传链路已恢复，但 `OSS_ACCESS_KEY_ID` / `OSS_ACCESS_KEY_SECRET` 仍通过 SAE 应用环境变量注入。

## 2. 影响范围
- 环境：`cn-hangzhou:bianlunmiao-prod`
- 应用：`bianlunmiao-backend-prod`
- 涉及变量：
  - `OSS_ACCESS_KEY_ID`
  - `OSS_ACCESS_KEY_SECRET`
  - `OSS_BUCKET`
  - `OSS_ENDPOINT`
  - `OSS_PUBLIC_BASE_URL`
  - `OSS_ENV_PREFIX=prod`

## 3. 已确认事实
- 生产 OSS 上传链路当前可用，健康检查正常。
- 生产专用 RAM 用户已创建：`blm-oss-prod-signer`
- 生产最小权限策略已创建并绑定：`BLMOSSProdSignerPolicy`
- 权限范围已限制到：`acs:oss:*:*:bianlunmiao-assets-1917380129637610/prod/*`
- SAE 当前仅存在镜像拉取 Secret：`acr-login-prod`
- SAE 业务 Secret 未创建成功。

## 4. CLI 实测记录
### 4.1 已成功
- `aliyun ram CreateUser --UserName blm-oss-prod-signer ...`
- `aliyun ram CreatePolicy --PolicyName BLMOSSProdSignerPolicy ...`
- `aliyun ram AttachPolicyToUser --PolicyType Custom --PolicyName BLMOSSProdSignerPolicy --UserName blm-oss-prod-signer`
- `aliyun ram CreateAccessKey --UserName blm-oss-prod-signer`
- `aliyun sae DeployApplication --AppId b8561560-2980-4443-87ce-32d3d19ee701 ...`

### 4.2 持续失败
- `aliyun sae CreateSecret --RegionId cn-hangzhou --NamespaceId cn-hangzhou:bianlunmiao-prod --SecretType Opaque ...`
- 典型报错：
  - `InvalidParameter.WithMessage`: `SecretName` 不符合 SAE 命名规则
  - `OperationFailed.RPCError`: 在名称修正后仍持续返回服务端内部 RPC 错误

## 5. 当前风险判断
- 风险级别：中
- 原因：
  - 生产链路已恢复，业务不阻塞。
  - 但敏感凭证仍为应用环境变量，不是 Secret 引用，暴露面大于目标设计。
- 不建议继续拖延到下一个大版本再处理，应在下一轮运维窗口完成 Secret 化和 AK 轮换。

## 6. 推荐收敛方案
1. 通过 SAE 控制台手动创建 `Opaque Secret`，名称建议：`blm-oss-prod-credentials`
2. Secret 内写入：
   - `OSS_ACCESS_KEY_ID`
   - `OSS_ACCESS_KEY_SECRET`
3. 在 `bianlunmiao-backend-prod` 中将上述两个变量改为 `secretRef`
4. 发布成功后，立即轮换并删除当前仍在用的旧 prod AccessKey
5. 完成后复验：
   - `POST /api/v1/media/avatar-upload-token`
   - 生产 App 头像上传
   - OSS 实际对象落到 `prod/avatars/...`

## 7. 手动处理口径
### 7.1 SAE 控制台
- 路径：`SAE` -> `命名空间` -> `辩论喵-生产环境` -> `Secrets`
- 新建类型：`Opaque`
- Secret 名称：`blm-oss-prod-credentials`

### 7.2 应用配置
- 路径：`SAE` -> `应用` -> `bianlunmiao-backend-prod` -> `部署配置` -> `环境变量`
- 保留为普通变量：
  - `OSS_BUCKET`
  - `OSS_ENDPOINT`
  - `OSS_PUBLIC_BASE_URL`
  - `OSS_ENV_PREFIX=prod`
- 改为 Secret 引用：
  - `OSS_ACCESS_KEY_ID`
  - `OSS_ACCESS_KEY_SECRET`

## 8. 验收标准
- SAE 应用不再展示明文 OSS AK/SK
- 生产 `/media/avatar-upload-token` 正常返回 200
- 生产头像上传成功
- 当前 prod signer 的旧 AccessKey 被删除

## 变更日志
- 2026-03-04: 初始化遗留问题文档，记录 SAE `Opaque Secret` 创建阻塞、当前兜底方案与后续收敛步骤。

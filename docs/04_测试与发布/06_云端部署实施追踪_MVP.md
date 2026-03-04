# 云端部署实施追踪（MVP）

[PROTOCOL]: 变更时更新此头部，然后检查 agents.md

**版本**: v1.24
**日期**: 2026-03-04

## 1. 目标与范围
1. 以最低成本完成后端云端可用部署，支持 iOS 联调。
2. 明确区分 `Staging` 与 `Prod`，避免“测试即生产”。
3. 使用同一套部署模板，避免维护两套系统。

不在本期范围：
1. 全量高可用（多可用区主备、自动扩缩容策略精调）。
2. 复杂网关编排与多地域容灾。

## 2. 当前技术基线
1. 后端：FastAPI + Alembic + PostgreSQL（目录：`辩论喵-后端`）。
2. iOS：通过 `baseURL` 连接后端。
3. 本地联调已可用，目标是迁移到阿里云可持续联调。

## 2.1 已确认云资源快照（2026-02-19）
| 资源 | 关键字段 | 当前值 | 后续用途 |
|---|---|---|---|
| VPC | VPC ID | `vpc-bp1rzf2520zp404pcqwda` | SAE/RDS 统一绑定网络 |
| VPC | 地域 | `华东1（杭州）` | 保持全部资源同地域 |
| vSwitch | vSwitch ID | `vsw-bp1wk9pcc2esj30bamlnx` | SAE/RDS 统一绑定交换机 |
| vSwitch | IPv4 网段 | `172.24.32.0/20` | 分配实例内网 IP |
| vSwitch | 可用区 | `杭州 可用区H` | RDS/SAE 创建时选同可用区 |
| vSwitch | 状态 | `可用` | 当前可直接复用，无需新建 |
| SAE 命名空间 | staging ID | `bianlunmiao-stg` | 测试环境发布与联调 |
| SAE 命名空间 | prod ID | `bianlunmiao-prod` | 生产环境发布 |

## 2.2 关键决策记录（计费与数据保留）
1. RDS 计费方式：MVP 阶段采用 `按量付费`（先跑通再评估包年包月）。
2. 按量付费开始计费时间：实例创建成功后即开始按小时计费。
3. 按量付费不是“按需启动计费”模式；仅停止调试不会自动停费。
4. 停费动作：需要释放实例，不能等同于关机。
5. 释放实例后的数据处理：可能进入回收站，但不保证长期保留；必须提前做手工备份。
6. 费用注意项：如启用跨地域备份，释放实例后仍可能产生异地备份相关费用。

## 2.3 已确认 RDS 创建参数快照（2026-02-19）
| 配置项 | 已确认值 |
|---|---|
| 计费方式 | 按量付费 |
| 地域 | 华东1（杭州） |
| 引擎版本 | PostgreSQL 16 |
| 产品系列 | 基础系列 |
| 网络类型 | 专有网络 |
| VPC | `vpc-bp1rzf2520zp404pcqwda` |
| vSwitch | `vsw-bp1wk9pcc2esj30bamlnx`（可用区H） |
| 部署方案 | 单可用区部署 |
| 规格 | `pg.n2.1c.1m`（1核2G） |
| 存储空间 | 20GB |
| 存储自动扩展 | 关闭 |
| 数据库端口 | 5432 |
| 小版本升级策略 | 手动升级 |
| 实例释放保护 | 开启 |
| 开通状态 | Running（已开通） |

## 2.4 自动化代操作能力检查（2026-02-19）
1. 当前会话未检测到可用阿里云 MCP 资源（MCP resources/templates 为空）。
2. 当前本机已安装并可用阿里云 CLI（`aliyun-cli 3.2.9`）。
3. 当前 skills 列表无阿里云部署专用 skill（仅有 Cloudflare 等其他平台）。
4. 已通过 OAuth profile `bianlunmiao` 完成鉴权并验证 `sts GetCallerIdentity`。
5. 结论：后续 RDS/SAE/ACR 常规运维可优先走 CLI 代操作。

## 2.5 CLI 配置进度（2026-02-19）
1. 已完成安装：`aliyun-cli 3.2.9`（Homebrew）。
2. 已验证命令可用：`aliyun --version` 正常。
3. 已完成认证：OAuth 模式 profile `bianlunmiao`。
4. 已验证权限：可读取/操作 RDS 资源。

## 2.6 RDS 初始化执行结果（CLI 代操作）
| 项目 | 结果 |
|---|---|
| DBInstanceId | `pgm-bp1v5t851p7rtl93` |
| 内网连接地址 | `pgm-bp1v5t851p7rtl93.pg.rds.aliyuncs.com` |
| 端口 | `5432` |
| 数据库 | `bianlunmiao_stg`、`bianlunmiao_prod` |
| 账号 | `app_stg`、`app_prod` |
| 权限 | `app_stg -> bianlunmiao_stg (ALL)`、`app_prod -> bianlunmiao_prod (ALL)` |
| 密码策略 | 已完成随机强密码轮换（凭证不写入仓库，仅在安全通道下发） |
| 白名单 | `default: 172.24.32.0/20`（已收敛到当前 vSwitch 网段） |

## 2.7 ACR 当前状态（2026-02-19）
1. `cr ListInstance` 返回 `0`，当前账号在 `cn-hangzhou` 尚无 ACR 实例。
2. CLI 可管理实例内命名空间/仓库，但实例创建涉及下单开通流程，不作为默认自动化步骤。
3. 后续动作：先完成一次性开通 ACR 实例，再由 CLI 自动创建命名空间与仓库。
4. 最新确认：已开通 ACR 个人版实例；`cr` OpenAPI 仍返回 `ListInstance=0`，个人版不使用企业版实例 ID 接口。
5. 结论：个人版场景下，命名空间/仓库创建采用控制台手工步骤；镜像构建、推送、SAE 配置继续使用 CLI 自动化。

## 2.8 后端容器化准备（2026-02-19）
1. 已新增后端镜像文件：
   - `辩论喵-后端/Dockerfile`
   - `辩论喵-后端/.dockerignore`
2. 构建命令：`docker build -t bianlunmiao-backend:local 辩论喵-后端`
3. 代理处理：通过临时 `DOCKER_CONFIG`（不继承 `~/.docker/config.json` 代理）完成构建。
4. 当前状态：本地镜像 `bianlunmiao-backend:local` 构建通过。

## 2.9 ACR 登录阻塞点（2026-02-19）
1. 个人版 ACR 需要“访问凭证”中的专用登录用户名。
2. 已尝试使用账号 ID 作为用户名登录 `registry.cn-hangzhou.aliyuncs.com`，返回鉴权失败。
3. 用户提供个人版凭证后，已验证登录成功：`docker login --username=<个人版用户名> crpi-*.personal.cr.aliyuncs.com`。
4. 后续动作：控制台完成仓库创建后，执行镜像 tag/push 与 SAE 部署。

## 2.10 ACR 镜像推送结果（2026-02-19）
| 项目 | 结果 |
|---|---|
| ACR 实例类型 | 个人版（华东1 杭州） |
| 命名空间/仓库 | `bianlunmiao/backend` |
| 公网仓库地址 | `crpi-5yg31t086w4thbmn.cn-hangzhou.personal.cr.aliyuncs.com/bianlunmiao/backend` |
| 专有网络仓库地址 | `crpi-5yg31t086w4thbmn-vpc.cn-hangzhou.personal.cr.aliyuncs.com/bianlunmiao/backend` |
| 首次推送 tag | `stg-20260219-01`（已确认为 arm64，SAE 不兼容） |
| 修正推送 tag | `stg-20260219-02`（`linux/amd64`） |
| 当前 staging 建议镜像 | `.../backend:stg-20260220-audit01` |

## 2.11 SAE staging 部署结果（2026-02-19）
| 项目 | 结果 |
|---|---|
| NamespaceId | `cn-hangzhou:bianlunmiao-stg` |
| AppName | `bianlunmiao-backend-stg` |
| AppId | `9922a4c5-70a4-4452-b5c4-b038bb7c1cd7` |
| 镜像拉取 Secret | `acr-login-stg`（SecretId=`5354`） |
| SAE 专用安全组 | `sg-bp1i7z69xtvqvywopg0h` |
| 失败原因修复 | `stg-20260219-01` 为 arm64，已切换到 amd64 镜像并重新发布 |
| 当前状态 | `CurrentStatus=RUNNING`，`RunningInstances=1`，`LastChangeOrderStatus=SUCCESS` |
| 未完成项 | 待补域名绑定与 HTTPS（当前已通过公网 IP 可访问） |

## 2.12 SAE 公网入口验证结果（2026-02-19）
| 项目 | 结果 |
|---|---|
| 公网 CLB 绑定 | 已完成（`Bind CLB` 变更单成功） |
| InternetSlbId | `lb-bp10eacwg0q6itc92xp1g` |
| InternetIp | `120.55.115.147` |
| 监听映射 | `80 -> 8000 (TCP)` |
| `GET /healthz` | `200`，返回 `{\"ok\":true}` |
| `GET /docs` | `200`，Swagger 页面可访问 |
| 当前 staging 临时基址 | `http://120.55.115.147` |

## 2.13 iOS Debug 联调切换进度（2026-02-19）
1. 已修改 iOS 远程网关基址解析逻辑：`bianlunmiao-ios/BianLunMiao/Data/RemoteGateway.swift`。
2. 新增规则：
   - 优先读取环境变量 `BLM_API_BASE_URL`。
   - `DEBUG` 默认：`http://120.55.115.147/api/v1`（当前 staging 临时入口）。
   - `RELEASE` 默认：`https://api.bianlunmiao.com/api/v1`（待后续域名与 HTTPS 完成后启用）。
3. 当前状态：代码已切换，待进行真机/模拟器冒烟请求验证。

## 2.14 API 鉴权链路冒烟与迁移修复（2026-02-19）
1. 问题：首次公网冒烟时，`POST /api/v1/auth/debug-token` 返回 `500`。
2. 根因：数据库迁移未实际执行到云端，导致业务表未初始化。
3. 处理：重新部署 `staging`，启动命令改为先执行迁移再启动服务：
   - `python -m alembic upgrade head && uvicorn app.main:app --host 0.0.0.0 --port 8000`
4. 同步修复：`DATABASE_URL` 改为原始密码字符（`!`），避免 `%21` 导致 Alembic 配置解析异常。
5. 结果：链路冒烟通过：
   - `POST /api/v1/auth/debug-token` -> `200`（返回 access_token）
   - `GET /api/v1/users/me` -> `200`（Bearer 鉴权成功）

## 2.15 域名解析进度（2026-02-19）
| 项目 | 结果 |
|---|---|
| 域名 | `bianlunmiao.top` |
| DNS 托管 | 阿里云 DNS（`dns15.hichina.com` / `dns16.hichina.com`） |
| 当前解析记录数 | `1` |
| 已创建测试域名 | `api-stg.bianlunmiao.top -> 120.55.115.147 (A, TTL=600)` |
| RecordId | `2024443538385529856` |
| 生产域名状态 | `api.bianlunmiao.top` 暂未创建（待 prod 公网入口） |

## 2.16 OSS 图片链路（Staging）落地结果（2026-02-20）
| 项目 | 结果 |
|---|---|
| OSS Bucket | `bianlunmiao-assets-1917380129637610` |
| 地域 | `cn-hangzhou` |
| 读策略 | `Bucket ACL=public-read` |
| 公共访问阻断 | `BlockPublicAccess=false`（已关闭阻断） |
| 生命周期 | `stg/` 前缀 30 天自动过期 |
| RAM 签名账号 | `blm-oss-stg-signer` |
| RAM 最小权限策略 | `BLMOSSStgSignerPolicy`（限制到 `stg/*` 前缀） |
| SAE 镜像发布 | `.../backend:stg-20260220-oss01` |
| SAE 变更单 | `363d202e-495b-480f-9f1a-47ff8a65022f`（`SUCCESS`） |

1. 后端 `/media/avatar-upload-token`、`/media/cover-upload-token` 已返回真实 OSS 预签名信息，返回体包含：`method=PUT`、`uploadHeaders`、`publicUrl`。
2. 实测上传通过：`PUT uploadUrl -> HTTP 200`（头像与封面各 1 次）。
3. 对象前缀验证通过：
   - `stg/avatars/2026/02/...jpg`
   - `stg/covers/2026/02/...jpg`
4. 未登录调用上传凭证接口返回 `401`（鉴权行为符合预期）。
5. 业务回写验证通过：`PUT /api/v1/users/me` 后，`avatarUrl` 已为 OSS URL（非本地路径）。

## 2.17 当前阻塞与影响（2026-02-20）
1. `api-stg.bianlunmiao.top` 当前访问命中 ICP 拦截页（HTTP 403），因此验收与联调暂使用 staging 公网 IP：`http://120.55.115.147`。
2. 不影响 OSS 链路本身可用性，但会影响“用正式测试域名做真机联调”的体验；后续需补齐备案/接入策略。

## 2.18 Prod 恢复执行结果（2026-03-02）
| 项目 | 结果 |
|---|---|
| 生产 SAE 应用 | `bianlunmiao-backend-prod` |
| Prod AppId | `b8561560-2980-4443-87ce-32d3d19ee701` |
| Prod 镜像 | `.../backend:prod-20260302-applefix01` |
| Prod 公网 SLB | `lb-bp11ko0r89ad8252el92z` |
| Prod 后端公网 IP | `121.43.226.231` |
| 正式域名 | `api.bianlunmiao.top -> 47.110.70.49` |
| HTTPS 入口 | `ECS(47.110.70.49) + Caddy 自动证书` |
| 正式健康检查 | `GET https://api.bianlunmiao.top/healthz -> 200` |
| 正式鉴权校验 | `GET /api/v1/users/me -> 401`（无凭证符合预期） |
| 正式 debug-token | `403 DEBUG_TOKEN_DISABLED` |
| 正式 Apple 校验 | `POST /api/v1/auth/apple` 对非法 token 返回 `401 APPLE_TOKEN_INVALID` |

1. 2026-03-02 实测确认：此前 `api.bianlunmiao.top` 指向的 ECS `47.110.70.49` 没有任何 Web 监听，且安全组未放通 `80/443`，导致正式域名完全不可用。
2. 本次恢复动作：
   - 构建并推送新后端镜像 `prod-20260302-applefix01`。
   - 在 `cn-hangzhou:bianlunmiao-prod` 创建 prod SAE 应用，并绑定公网 SLB `121.43.226.231:80 -> 8000`。
   - 打开 ECS 安全组 `80/443`，使用系统包 `caddy` 在 ECS 上承接 `api.bianlunmiao.top` 的 HTTPS 入口并反代到 prod SAE。
3. 当前结论：正式域名、正式 HTTPS、正式后端应用均已恢复可用；iOS Release/TestFlight/App Store 继续指向 `https://api.bianlunmiao.top/api/v1`。

## 2.19 Prod Apple JWKS 热修结果（2026-03-03）
| 项目 | 结果 |
|---|---|
| 首次热修镜像 | `.../backend:prod-20260303-applejwks01` |
| 二次热修镜像 | `.../backend:prod-20260303-applejwks02` |

## 2.20 Prod OSS signer 落地结果（2026-03-04）
| 项目 | 结果 |
|---|---|
| Prod RAM 用户 | `blm-oss-prod-signer` |
| Prod 自定义策略 | `BLMOSSProdSignerPolicy` |
| OSS Bucket | `bianlunmiao-assets-1917380129637610` |
| Prod 前缀 | `prod/*` |
| SAE 生产应用 | `bianlunmiao-backend-prod` |
| 发布结果 | `LastChangeOrderStatus=SUCCESS` |

1. 已通过阿里云 CLI 创建生产专用 OSS signer RAM 用户与最小权限策略，权限限制到 `prod/*` 前缀。
2. 已将生产 SAE 应用补充 OSS 相关环境变量：`OSS_BUCKET`、`OSS_ENDPOINT`、`OSS_ACCESS_KEY_ID`、`OSS_ACCESS_KEY_SECRET`、`OSS_PUBLIC_BASE_URL`、`OSS_ENV_PREFIX=prod`。
3. 本次目标是先恢复生产头像/封面上传能力；当前生产凭证仍以 SAE 应用环境变量形式注入，未完成 Secret 化。
4. 阻塞记录：尝试通过 SAE OpenAPI/CLI 创建 `Opaque` Secret 时持续返回 `OperationFailed.RPCError`，后续需要改走控制台创建或排查 SAE Secret API 可用性。
5. 后续安全动作：
   - 将 `OSS_ACCESS_KEY_ID` / `OSS_ACCESS_KEY_SECRET` 从明文环境变量迁移到 SAE Secret。
   - 评估同批次迁移 `DATABASE_URL`、`SECRET_KEY` 等现有敏感变量。
| 当前正式镜像 | `.../backend:prod-20260303-applejwks03` |
| 最新变更单 | `4691f3ea-8bed-403a-bcf4-e0171cb41db0`（`SUCCESS`） |
| Prod 健康检查 | `GET https://api.bianlunmiao.top/healthz -> 200` |
| Prod Apple 伪造 token 冒烟 | `POST /api/v1/auth/apple -> 401 APPLE_TOKEN_INVALID / Apple token 签名校验失败` |

1. 2026-03-03 实测发现：iOS 真机点击 `Sign in with Apple` 后，后端始终返回“无法获取 Apple 公钥”。
2. 排查结果：
   - 生产 SAE 运行环境无法稳定直连 `https://appleid.apple.com/auth/keys`。
   - 单纯补系统 CA 证书与绕过代理后，线上仍无法在运行时拉取 Apple JWKS。
3. 本次热修动作：
   - 在后端 Apple token 校验器中加入 JWKS 内存缓存。
   - 校验器改为显式绕过运行时代理创建 TLS 连接。
   - 新增配置 `APPLE_JWKS_FALLBACK_JSON`，当 prod 运行环境无法直连 Apple 时，回退到预置 Apple JWKS JSON 继续做真实签名校验。
   - 将当前 Apple JWKS 作为 fallback 注入 prod SAE 环境。
4. 当前结论：prod 已不再卡在“无法获取 Apple 公钥”，而是能进入真实签名校验路径；对伪造 token 的返回已从“取不到公钥”变为“签名校验失败”。

## 2.21 Prod Apple kid 轮换热修（2026-03-04）
| 项目 | 结果 |
|---|---|
| 问题现象 | iOS 真机 Apple 登录返回 `401 APPLE_TOKEN_INVALID / 未找到匹配的 Apple 公钥` |
| 根因 | 生产环境在无法稳定直连 Apple JWKS 时，只能依赖旧 fallback；当 Apple 新发 token 的 `kid` 不在旧缓存/旧 fallback 内时，校验器会直接失败 |
| 本次修复 | `kid` 未命中时强制回源刷新 JWKS；镜像内置一份最新 Apple JWKS，并与 `APPLE_JWKS_FALLBACK_JSON` 合并作为兜底 |
| 发布镜像 | `.../backend:prod-20260304-applekid01` |
| SAE 变更单 | `25c7df41-65d1-48fa-936c-fad5e2279359`（`SUCCESS`） |
| 验证 | 后端回归测试通过；prod `/healthz -> 200`；带当前有效 `kid` 的伪造 Apple token 返回 `401 APPLE_TOKEN_INVALID / Apple token 签名校验失败` |

1. 这次故障与上一次“完全取不到 Apple 公钥”不同，本次是“取到了旧 key，但匹配不到当前 token 的 `kid`”。
2. 修复后，即使进程里已经缓存了旧 JWKS，只要当前 token 的 `kid` 未命中，也会立刻绕过缓存再拉一次 Apple JWKS。
3. 若生产 SAE 仍然无法稳定出网拉取 Apple，后端会继续使用镜像内置 JWKS 与环境变量中的 `APPLE_JWKS_FALLBACK_JSON` 合并校验，避免只依赖单份易过期配置。
4. 已同步刷新 prod SAE 中的 `APPLE_JWKS_FALLBACK_JSON` 到 Apple 当前 JWKS，旧 `kid` `bFwzleR8tf` 已从线上 fallback 移除。

## 3. MVP 目标架构（最小成本）
1. 计算：`SAE`（同地域，双命名空间：`staging`、`prod`）。
2. 数据：`RDS PostgreSQL` 单实例双库（`bianlunmiao_stg`、`bianlunmiao_prod`）。
3. 镜像：`ACR`（同一镜像，先发 staging，再升格 prod）。
4. 网络：单 `VPC` + 单 `vSwitch` + 单安全组。
5. 访问：
   - `staging`: `api-stg.bianlunmiao.top`（已接入）。
   - `prod`: `api.bianlunmiao.top` + HTTPS（待接入）。
6. 监控：`CloudMonitor`（资源告警 + 可用性基础告警）。

## 4. Staging / Prod 隔离规则
1. 环境隔离：不同 SAE 命名空间。
2. 数据隔离：不同数据库与账号，禁止共用同一账号。
3. 配置隔离：不同 `DATABASE_URL`、`SECRET_KEY`、`APP_ENV`。
4. 访问隔离：不同 URL；iOS Debug 指向 staging，Release 指向 prod。
5. 发布隔离：同镜像 Tag，先过 staging 验收再部署 prod。

## 5. 第一阶段：阿里云采购与配置清单（现在执行）

### 5.1 必采资源（MVP 必需）
| 资源 | 规格建议（MVP） | 用途 | 备注 |
|---|---|---|---|
| VPC + vSwitch + 安全组 | 1 套（华东 1） | 私网互通与访问控制 | 通常免费 |
| SAE | 2 命名空间（staging/prod） | 部署 FastAPI 服务 | 同一应用模板 |
| RDS PostgreSQL | 1 实例（入门规格） | 持久化数据库 | 2 库 + 2 账号 |
| ACR | 1 个人版实例/命名空间 | 镜像仓库 | 供 SAE 拉镜像 |
| OSS | 1 Bucket（按量） | 图片对象存储 | `stg/` 生命周期 30 天 |
| CloudMonitor | 基础告警 | 可用性与成本预警 | 免费层可先用 |

### 5.2 暂不采购（MVP 延后）
1. Redis（当前后端未体现强依赖，可后补）。
2. ALB / API 网关（先用 SAE 入口，流量增长再加）。
3. SLS 全量日志（先用基础日志，稳定后再集中化）。

### 5.3 必配项（按顺序）
1. 地域统一：全部资源放 `华东1（杭州）`。
2. SAE 命名空间：`bianlunmiao-stg`、`bianlunmiao-prod`。
3. RDS：
   - 数据库：`bianlunmiao_stg`、`bianlunmiao_prod`
   - 账号：`app_stg` 仅 stg 库权限，`app_prod` 仅 prod 库权限
4. 网络白名单：将 SAE 出网地址按官方流程加入 RDS 白名单。
5. ACR 仓库：`bianlunmiao/backend`。
6. SAE 环境变量（两环境分别配置）：
   - `APP_ENV` = `staging` / `prod`
   - `DATABASE_URL` = 对应 RDS 库连接串
   - `SECRET_KEY` = 环境独立随机值
   - `ACCESS_TOKEN_EXPIRE_MINUTES` = `120`
   - `REFRESH_TOKEN_EXPIRE_MINUTES` = `43200`
   - `ENABLE_DEBUG_TOKEN` = `true`(staging) / `false`(prod)
7. iOS 配置：
   - Debug -> `https://api-stg.<your-domain>`
   - Release -> `https://api.<your-domain>`

### 5.4 RDS 创建参数模板（当前执行口径）
| 配置项 | 建议值 | 说明 |
|---|---|---|
| 计费方式 | 按量付费 | MVP 最小成本、先验证后固化 |
| 地域 | 华东1（杭州） | 与 SAE 同地域 |
| 引擎 | PostgreSQL 16 | 与本地开发环境一致 |
| 产品系列 | 基础系列 | 控制成本 |
| 存储类型 | 高性能云盘 | 默认即可 |
| 网络类型 | 专有网络 | 内网访问 |
| VPC | `vpc-bp1rzf2520zp404pcqwda` | 复用现有网络 |
| 主可用区及网络 | 杭州可用区H / `vsw-bp1wk9pcc2esj30bamlnx` | 与现有 vSwitch 一致 |
| 加入白名单 | 是（MVP） | 先保证联通，后续再收敛权限 |
| 部署方案 | 单可用区部署 | MVP 降成本 |
| 规格 | `pg.n2.1c.1m`（1核2G） | 先小规格，压测后再升 |
| 存储空间 | 20GB（起步） | 不建议首配 100GB |
| 存储空间自动扩展 | 关闭（MVP） | 避免费用不可控 |
| 公网访问 | 关闭 | 仅内网，提升安全性 |
| 释放保护 | 开启 | 防误释放 |

### 5.5 采购完成判定（DoD）
1. SAE staging/prod 命名空间均可见。
2. RDS 双库双账号已创建，且权限正确。
3. ACR 可成功推送与拉取镜像。
4. staging 环境已可通过公网 URL 访问 `/docs`。

## 6. 执行看板（持续追踪）
| 编号 | 任务 | 负责人 | 状态 | 截止日期 | 备注 |
|---|---|---|---|---|---|
| M1-1 | 创建 VPC/vSwitch/安全组 | 待定 | DONE | 2026-02-20 | 已复用现有 VPC/vSwitch，并创建 SAE 专用安全组 |
| M1-2 | 创建 SAE staging/prod 命名空间 | 待定 | DONE | 2026-02-20 | 已创建 `bianlunmiao-stg`、`bianlunmiao-prod` |
| M1-3 | 创建 RDS 实例+双库双账号 | 待定 | DONE | 2026-02-20 | CLI 已完成双库双账号创建与授权 |
| M1-4 | 创建 ACR 并建立仓库 | 待定 | DONE | 2026-02-20 | 个人版仓库已创建，镜像已推送（含 amd64 tag） |
| M1-5 | 配置 RDS 白名单 | 待定 | DONE | 2026-02-20 | 已收敛为 `172.24.32.0/20` |
| M1-6 | 部署 staging 并验收 `/docs` | 待定 | DONE | 2026-02-20 | 已通过公网 IP 验收 `/healthz` 与 `/docs` |
| M1-7 | iOS Debug 切到 staging | 待定 | IN_PROGRESS | 2026-02-21 | 代码已切换，待运行 App 完成冒烟 |
| M1-8 | 配置公网 Ingress/SLB 与访问域名 | 待定 | DONE | 2026-03-02 | `api-stg` 与 `api`（prod HTTPS）均已恢复 |
| M1-9 | 接入 OSS（staging）并跑通头像/封面上传 | 待定 | DONE | 2026-02-20 | 已完成 token->直传->回写链路与 API 验收 |
| M1-10 | 处理 `api-stg` 域名 ICP 拦截问题 | 待定 | IN_PROGRESS | 2026-02-21 | 当前临时使用公网 IP 联调 |

## 7. 变更日志
- 2026-02-19: 新建云端部署实施追踪文档，定义 MVP 架构与第一阶段采购配置清单。
- 2026-02-19: 记录已确认 VPC/vSwitch 资源快照，更新 M1-1 为进行中状态。
- 2026-02-19: 记录 SAE staging/prod 命名空间已创建，更新 M1-2 为完成状态。
- 2026-02-19: 补充计费/释放关键决策记录与 RDS 创建参数模板，更新 M1-3 为进行中状态。
- 2026-02-19: 记录 RDS 已开通及创建参数快照，M1-3 进入数据库初始化阶段。
- 2026-02-19: 补充自动化代操作能力检查结论（当前无阿里云 MCP/CLI）。
- 2026-02-19: 完成 aliyun-cli 安装并记录 credential 待配置状态。
- 2026-02-19: 完成 CLI OAuth 鉴权与 RDS 初始化代操作，更新 M1-3 为完成状态。
- 2026-02-19: 收敛 RDS 白名单到 `172.24.32.0/20`，更新 M1-5 为完成状态。
- 2026-02-19: 补充 ACR 当前状态（实例数为 0）与后续开通动作，更新 M1-4 为进行中。
- 2026-02-19: 完成数据库账号密码轮换，并补充凭证不入库说明。
- 2026-02-19: 确认 ACR 个人版已开通但不走企业版实例 API，调整 M1-4 执行路径为“控制台建仓 + CLI 自动化后续”。
- 2026-02-19: 新增后端 Dockerfile/.dockerignore，记录当前构建受本机 Docker 代理配置影响。
- 2026-02-19: 通过临时 Docker 配置完成本地镜像构建验证，新增 ACR 登录用户名阻塞记录。
- 2026-02-19: 已验证 ACR 个人版访问凭证可登录，进入仓库创建与镜像推送阶段。
- 2026-02-19: ACR 仓库 `bianlunmiao/backend` 已完成镜像推送；新增 `stg-20260219-02`（amd64）作为 staging 可用镜像。
- 2026-02-19: SAE staging 应用创建完成并成功运行（1 实例）；记录 AppId、SecretId、安全组与变更单结果。
- 2026-02-19: SAE 已绑定公网 CLB（`120.55.115.147`），并完成 `/healthz`、`/docs` 联通验收。
- 2026-02-19: iOS RemoteGateway 新增 `BLM_API_BASE_URL` 覆盖能力，Debug 默认切换到 staging 公网地址。
- 2026-02-19: 修复 staging 迁移未执行问题，改为启动前执行 Alembic；`/api/v1` 鉴权链路冒烟通过。
- 2026-02-19: 完成 `api-stg.bianlunmiao.top` 测试域名解析（A 记录指向 `120.55.115.147`），并明确 prod 域名待接入。
- 2026-02-20: 完成 OSS 资源落地（Bucket、`stg/` 生命周期、最小权限 RAM 策略）并为 SAE staging 注入 OSS 环境变量。
- 2026-02-20: 后端媒体上传接口切换为真实 OSS 预签名；返回结构扩展 `method/uploadHeaders/publicUrl` 并校验 `stg/` 路径白名单。
- 2026-02-20: iOS 上传链路切换为“拿 token -> 直传 OSS -> 回填业务 URL”，并补充远程 URL 图片渲染兼容。
- 2026-02-20: ACR 新镜像 `stg-20260220-oss01` 发布至 SAE 成功，完成 staging 端到端上传验收（头像/封面 PUT 200，公网 URL 可读）。
- 2026-02-20: 修正执行看板 M1-6 截止日期与完成状态的时间一致性，避免未来日期已完成的歧义。
- 2026-02-20: 执行 staging 数据清理（`bianlunmiao_stg` 删库重建 + SAE 重启迁移），回到干净联调基线。
- 2026-02-20: 发布镜像 `stg-20260220-audit01` 到 SAE staging，修复 `debug-token` 超长 `public_id` 导致的 500，改为 422 参数校验错误。
- 2026-03-02: 构建并推送镜像 `prod-20260302-applefix01`，补建 prod SAE 应用 `bianlunmiao-backend-prod`，恢复正式后端实例。
- 2026-03-02: 为 prod SAE 绑定公网 SLB `121.43.226.231`，并通过 ECS `47.110.70.49` 上的 Caddy 恢复 `api.bianlunmiao.top` HTTPS 入口。
- 2026-03-02: 实测正式域名恢复可用：`/healthz` 返回 `200`，`/api/v1/users/me` 未授权返回 `401`，`debug-token` 返回 `403 DEBUG_TOKEN_DISABLED`，非法 Apple token 返回 `401 APPLE_TOKEN_INVALID`。
- 2026-03-04: 修复 prod Apple 登录 `kid` 不匹配问题；后端在 JWKS miss 时强制刷新，并加入镜像内置 Apple JWKS fallback。
- 2026-03-04: 发布镜像 `prod-20260304-applekid01` 到 prod SAE，刷新线上 `APPLE_JWKS_FALLBACK_JSON`，发布后健康检查与 Apple `kid` 冒烟通过。

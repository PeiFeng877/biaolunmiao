# 辩论喵-后端（FC 单正式环境）

FastAPI 后端服务，当前面向 `辩论喵-iOS` 的单环境重构基线。客户端统一走 `POST /api` RPC 单入口，服务内部仍复用 `/api/v1` 资源路由。

## 1. 目录

```text
辩论喵-后端
├── app
│   ├── api/v1
│   ├── core
│   ├── db
│   ├── models
│   └── schemas
├── alembic
├── scripts
├── tests
├── docker-compose.yml
├── pyproject.toml
└── README.md
```

跨端规范与契约文档统一维护在主目录：
`/Users/Icarus/Documents/project/bianlunmiao/docs`

## 2. 本地启动

1. 启动基础依赖

```bash
docker compose up -d
```

2. 安装依赖（任选一种）

```bash
python -m venv .venv
source .venv/bin/activate
pip install -e .[dev]
```

3. 配置环境

```bash
cp .env.example .env
```

对象存储联调说明：
- 使用长期 RAM AK/SK 时，填写 `OSS_BUCKET`、`OSS_ENDPOINT`、`OSS_ACCESS_KEY_ID`、`OSS_ACCESS_KEY_SECRET`。
- 使用阿里云 CLI 的 OAuth / STS 临时凭证时，除上述字段外还需要填写 `OSS_SECURITY_TOKEN`。
- 本地进程只读取 `.env`，不会自动继承 `aliyun` CLI profile。

4. 执行迁移

```bash
alembic upgrade head
```

5. 初始化种子

```bash
python -m scripts.seed_data
```

6. 启动 API

```bash
uvicorn app.main:app --reload --port 8000
```

OpenAPI: [http://127.0.0.1:8000/docs](http://127.0.0.1:8000/docs)

## 3. 当前入口

- 健康检查：`GET /healthz`
- 客户端 RPC：`POST /api`
- 内部资源路由：`/api/v1/*`
- 本地上传（仅 `MEDIA_BACKEND=local`）：`PUT /uploads/<objectKey>` 与 `GET /uploads/<objectKey>`

## 4. iOS 联调入口

- iOS Debug（模拟器）：`http://127.0.0.1:8000`
- iOS Debug（真机）：按 iOS `BLM_API_BASE_URL` 指向显式配置
- iOS Release / TestFlight：先走 FC 默认域名根地址，客户端自动拼接到 `/api`
- 当前不再保留云端 `stg` 环境

建议联调顺序：
1. 本地 `POST /api` 调 `auth.debug_token` 获取 token。
2. 带 `Authorization: Bearer <access_token>` 访问其他动作。
3. 先联调 `users/teams`，再联调 `tournaments/matches/media`。

## 5. 媒体策略

- 本地默认 `MEDIA_BACKEND=local`，上传令牌会返回当前服务的 `/uploads/*` 地址，便于模拟器/真机直连。
- 正式环境切到 `MEDIA_BACKEND=oss`，并配置 `OSS_*` 变量。
- `OSS_ENV_PREFIX` 默认使用 `prod`，不再保留 `stg` 前缀。

## 6. FC / RDS 自动化

1. 新购杭州 `RDS PostgreSQL Serverless`：

```bash
./scripts/create_rds_serverless.sh
```

2. 构建 FC 代码包：

```bash
./scripts/build_fc_zip.sh
```

3. 准备正式环境变量文件：

```bash
cp .env.fc.prod.example .env.fc.prod.local
```

4. 发布或更新 FC 函数：

```bash
./scripts/deploy_fc_zip.sh
```

说明：
- `deploy_fc_zip.sh` 会输出 `FC_URL`，把它回写到 iOS 的 `BLM_PROD_API_BASE_URL` 即可让 TestFlight 先走 FC 默认域名。
- `deploy_fc_zip.sh` 会先把代码包上传到现有 `OSS` bucket，再让 `FC` 从 `OSS` 拉取代码，避免命令行 body 过长。
- `RUN_MIGRATIONS_ON_BOOT=true` 时，函数冷启动会先执行 `alembic upgrade head`；新库首启建议保持开启。
- 若需要 VPC 直连私网 RDS，部署前补齐 `FC_VPC_ID`、`FC_VSWITCH_ID`、`FC_SECURITY_GROUP_ID` 与可选 `FC_ROLE_ARN`。
- 当前 FC 脚手架不再依赖 ACR，直接用代码包部署。

## 7. Apple 登录约束

- `POST /api/v1/auth/apple` 路径与请求体保持不变，但生产语义已升级为真实 Apple identity token 校验。
- 生产环境必须满足：
  - `APP_ENV=prod`
  - `ALLOW_INSECURE_APPLE_TOKEN_VALIDATION=false`
  - `ENABLE_DEBUG_TOKEN=false`
  - `APPLE_ALLOWED_AUDIENCES` 包含正式 iOS Bundle ID
- 本地/测试环境可以开启 `ALLOW_INSECURE_APPLE_TOKEN_VALIDATION=true`，用于联调占位 token，但不能用于正式服。
- 默认 Apple JWKS 地址：`https://appleid.apple.com/auth/keys`
- `APPLE_JWKS_FALLBACK_JSON` 可选；当运行环境无法直连 Apple 时，生产环境会将该配置与镜像内置 Apple JWKS 合并后继续做签名校验。
- 后端会显式创建 TLS 上下文并绕过运行时代理拉取 Apple JWKS，并在进程内缓存 10 分钟以减少外部依赖抖动。
- 若缓存中的 JWKS 无法匹配当前 token 的 `kid`，校验器会强制回源刷新一次，避免旧缓存或旧 fallback 长时间卡死正式登录。

## 8. 当前状态

- 已实现：`GET /healthz`、`POST /api`、`/api/v1/*` 资源路由与本地上传回环。
- 已实现：Auth/User/Team/JoinRequest/Tournament/Match/Roster/Result/Schedule/Message/Media 的 MVP 接口骨架与核心规则。
- 已实现：统一错误体 `{code, message, requestId, details?}`。
- 已实现：Alembic 初始迁移、docker compose、基础种子脚本。
- 已实现：Apple token 的 issuer / audience / exp / sub / 签名校验，以及 prod 环境的 insecure 校验保护。
- 后续增强：FC 默认域名部署脚手架、RDS Serverless 初始化、推送链路、更完整权限域与审计。

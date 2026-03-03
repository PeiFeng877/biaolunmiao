# 辩论喵-后端（MVP 1.0）

FastAPI 后端服务，承接 `辩论喵-iOS` 当前本地 Mock 业务，提供统一 `/api/v1` 接口给 iOS/Android 复用。

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

## 3. iOS 联调入口

- iOS Debug（模拟器）：`http://127.0.0.1:8000`
- iOS Debug（真机/测试服）：按 iOS `BLM_API_BASE_URL` 指向显式配置
- iOS Release / TestFlight / App Store：固定走正式域名 `https://api.bianlunmiao.top/api/v1`
- API 前缀：`/api/v1`

建议联调顺序：
1. `POST /api/v1/auth/debug-token` 获取 token。
2. 带 `Authorization: Bearer <access_token>` 访问其他接口。
3. 先联调 `users/teams`，再联调 `tournaments/matches`。

## 4. Apple 登录约束

- `POST /api/v1/auth/apple` 路径与请求体保持不变，但生产语义已升级为真实 Apple identity token 校验。
- 生产环境必须满足：
  - `APP_ENV=prod`
  - `ALLOW_INSECURE_APPLE_TOKEN_VALIDATION=false`
  - `ENABLE_DEBUG_TOKEN=false`
  - `APPLE_ALLOWED_AUDIENCES` 包含正式 iOS Bundle ID
- 本地/测试环境可以开启 `ALLOW_INSECURE_APPLE_TOKEN_VALIDATION=true`，用于联调占位 token，但不能用于正式服。
- 默认 Apple JWKS 地址：`https://appleid.apple.com/auth/keys`
- `APPLE_JWKS_FALLBACK_JSON` 可选；当运行环境无法直连 Apple 时，生产环境可回退到预置的 Apple JWKS JSON 继续做签名校验。
- 运行镜像必须具备系统 CA 证书；后端会显式创建 TLS 上下文并绕过运行时代理拉取 Apple JWKS，并在进程内缓存 10 分钟以减少外部依赖抖动。

## 5. 当前状态

- 已实现：Auth/User/Team/JoinRequest/Tournament/Match/Roster/Result/Schedule/Message/Media 的 MVP 接口骨架与核心规则。
- 已实现：统一错误体 `{code, message, requestId, details?}`。
- 已实现：Alembic 初始迁移、docker compose、基础种子脚本。
- 已实现：Apple token 的 issuer / audience / exp / sub / 签名校验，以及 prod 环境的 insecure 校验保护。
- 后续增强：OSS 真正预签名、推送链路、更完整权限域与审计。

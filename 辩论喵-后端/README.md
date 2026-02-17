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
- iOS Debug（真机）：`http://<电脑局域网IP>:8000`
- API 前缀：`/api/v1`

建议联调顺序：
1. `POST /api/v1/auth/debug-token` 获取 token。
2. 带 `Authorization: Bearer <access_token>` 访问其他接口。
3. 先联调 `users/teams`，再联调 `tournaments/matches`。

## 4. 当前状态

- 已实现：Auth/User/Team/JoinRequest/Tournament/Match/Roster/Result/Schedule/Message/Media 的 MVP 接口骨架与核心规则。
- 已实现：统一错误体 `{code, message, requestId, details?}`。
- 已实现：Alembic 初始迁移、docker compose、基础种子脚本。
- 后续增强：Apple 真实公钥校验、OSS 真正预签名、推送链路、更完整权限域与审计。

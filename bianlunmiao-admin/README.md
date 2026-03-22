# 辩论喵 Web 管理后台

基于 `Next.js + TypeScript + shadcn/ui` 的内部管理端，负责用户、队伍、赛事三类数据管理。

## 模块边界

- 仅保留源码、文档与必要构建配置，运行产物不纳入版本控制。
- 主要页面分为 `/login`、`/dashboard`、`/users`、`/teams`、`/tournaments`。
- 管理端统一通过 `POST /api` 的 RPC 动作访问后端，不复用 App 用户会话。
- 管理员会话与 App 用户会话隔离，页面内不提供环境切换器。

## 本地启动

1. 安装依赖

```bash
pnpm install
```

2. 配置环境

```bash
cp .env.example .env.local
```

3. 启动开发服务

```bash
pnpm dev
```

默认访问 [http://localhost:3000](http://localhost:3000)。

## 环境变量

- `NEXT_PUBLIC_APP_ENV`: `local | prod`
- `NEXT_PUBLIC_API_BASE_URL`: 浏览器请求入口，推荐固定为同源 `/api/proxy`
- `INTERNAL_API_BASE_URL`: 管理端服务端代理的真实后端根地址，例如 FC 默认域名。

## 部署

- `Vercel prod`：`NEXT_PUBLIC_APP_ENV=prod`、`NEXT_PUBLIC_API_BASE_URL=/api/proxy`、`INTERNAL_API_BASE_URL=<FC 默认域名>`
- 页面内不提供环境切换器，环境隔离通过部署配置完成。
- 当前只保留本地联调和正式部署两态，历史 `stg` 配置已从主路径移除。

## 质量门禁

```bash
pnpm lint
pnpm build
```

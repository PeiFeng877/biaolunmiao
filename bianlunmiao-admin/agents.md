# agents.md

[PROTOCOL]: 变更时更新此头部，然后检查 agents.md

**版本**: v1.2
**日期**: 2026-03-20
**适用范围**: `/Users/Icarus/Documents/project 2026/bianlunmiao/bianlunmiao-admin`

## 1. 模块职责
1. 承载辩论喵 Web 管理后台的前端实现、页面状态、组件封装与端内文档。
2. 仅维护管理端实现细节；跨端接口、环境与数据契约以根目录 `docs/` 为 SSOT。

## 2. 目录结构
```text
./bianlunmiao-admin
├── agents.md
├── README.md
├── .gitignore
├── .env.example
├── app/
│   ├── layout.tsx
│   ├── page.tsx
│   ├── (auth)/login/page.tsx
│   ├── api/proxy/[...path]/route.ts
│   └── (dashboard)/
│       ├── dashboard/page.tsx
│       ├── layout.tsx
│       ├── teams/page.tsx
│       ├── tournaments/page.tsx
│       └── users/page.tsx
├── components/
│   ├── admin/
│   └── ui/
├── lib/
│   ├── api/
│   ├── auth/session.ts
│   ├── schemas/admin.ts
│   ├── format.ts
│   ├── forms.ts
│   └── utils.ts
├── public/
├── package.json
├── components.json
├── eslint.config.mjs
├── next.config.ts
├── pnpm-lock.yaml
├── pnpm-workspace.yaml
├── postcss.config.mjs
└── tsconfig.json
```

## 3. 开发约束
1. 页面与组件统一使用 `shadcn/ui` 作为基础组件来源，避免自造风格分叉。
2. 环境通过部署配置区分 `local/stg/prod`，禁止在页面内手动切环境。
3. 业务数据只读/写 `api/v1/admin/*`，不得直接依赖 App 用户接口做后台管理。
4. 后台鉴权状态仅服务 Web 管理端，不复用 App 用户 token 语义。
5. `next-env.d.ts`、`.next/`、`node_modules/`、`.vercel/`、`.env.local`、`.DS_Store` 属于本地产物，只作为忽略项存在，不纳入版本控制。

## 4. 质量门禁
1. `pnpm lint`
2. `pnpm build`

## 变更日志
- 2026-03-20: 移除不存在的 `CLAUDE.md`，补齐 `app/layout.tsx`、`app/page.tsx`、`app/api/proxy/[...path]/route.ts`、`.gitignore`、`.env.example` 与 `lib/` 真实结构，同步明确 `next-env.d.ts` 为忽略项。
- 2026-03-19: 补全 Web 管理后台目录边界与本地产物排除规则，明确 `app/`、`components/`、`lib/`、`public/` 与构建配置的职责。
- 2026-03-19: 初始化 Web 管理后台 L2 协作文档，明确独立模块边界与质量门禁。

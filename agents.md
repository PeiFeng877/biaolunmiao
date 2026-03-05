# agents.md

[PROTOCOL]: 变更时更新此头部，然后检查 agents.md

**版本**: v1.0
**日期**: 2026-03-05
**适用范围**: `/Users/Icarus/Documents/project/bianlunmiao/辩论喵-后端`

## 1. 模块职责
1. 承载辩论喵后端 API、鉴权、数据模型、迁移与测试实现。
2. 仅维护后端端内文档与实现细节；跨端契约以根目录 `docs/` 为 SSOT。

## 2. 目录结构
```text
./辩论喵-后端
├── agents.md
├── README.md
├── app/
├── alembic/
├── scripts/
├── tests/
├── Dockerfile
├── docker-compose.yml
├── pyproject.toml
└── Makefile
```

## 3. 开发约束
1. 任何 API 字段、错误码语义变化，先更新根目录 `docs/03_接口与数据契约/` 再改实现。
2. 数据库结构变更必须同步 Alembic 迁移与测试用例。
3. 代码改动需通过 `make lint` 与 `make test`。

## 4. 质量门禁
1. `make lint`
2. `make test`

## 变更日志
- 2026-03-05: 初始化后端 L2 协作文档，补齐分形文档系统层级约束。

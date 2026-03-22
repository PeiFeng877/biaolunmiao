# EMAS Serverless 官方资料

## 1. OpenAPI 与控制面
- [OpenAPI 门户上的 `mpserverless` 产品页面示例](https://api.aliyun.com/meta/v1/products/mpserverless/versions/2019-06-15/apis/CreateFunction)
  - 可确认产品码 `mpserverless`、版本 `2019-06-15` 与操作名存在。
- [官方控制面 Node SDK：`@alicloud/mpserverless20190615`](https://www.npmjs.com/package/@alicloud/mpserverless20190615)
  - 官方发布的 MPServerless 控制面 SDK，可直接调用 `DescribeSpaces`、`DescribeSpaceClientConfig`、`CreateFunction`、`UpdateHttpTriggerConfig`、`RunDBCommand` 等 OpenAPI。
- [通过 CLI 调用 OpenAPI 的官方说明](https://help.aliyun.com/zh/openapi/call-apis-by-using-cli)
  - 说明阿里云 CLI 可直接调用 OpenAPI；但本机 `aliyun 3.2.9` 未内置 `mpserverless` 产品命令，当前仓库不再把它当成主入口。
- [阿里云 OpenAPI MCP 代理](https://help.aliyun.com/zh/openapi/use-aliyun-mcp-proxy-agent-openapi-mcp-server)
  - 说明可通过 `aliyun mcp-proxy` 接入 OpenAPI MCP。

## 2. EMAS Serverless 运行时
- [Node.js SDK 文档](https://help.aliyun.com/zh/document_detail/435902.html)
  - 明确 `@alicloud/mpserverless-node-sdk`
  - 明确 `serverSecret` 来自 `DescribeSpaceClientConfig`
  - 明确 runtime endpoint 格式为 `https://api.next.bspapp.com` 一类服务空间 endpoint

## 3. 已确认可自动化的 EMAS 操作
- [小程序云审计事件列表](https://help.aliyun.com/zh/actiontrail/product-overview/audit-events-of-mini-program-cloud)
  - 可确认以下控制面操作存在：
    - `DescribeSpaces`
    - `DescribeSpaceClientConfig`
    - `CreateFunction`
    - `CreateFunctionDeployment`
    - `DeployFunction`
    - `DescribeHttpTriggerConfig`
    - `UpdateHttpTriggerConfig`
    - `AddCorsDomain`
    - `DeleteCorsDomain`
    - `RunDBCommand`
    - `ResetServerSecret`
    - `UpdateSpace`

## 4. 当前仓库的实践结论
- 控制面最适合走官方 Node SDK `@alicloud/mpserverless20190615`
- 已验证控制面 endpoint 为 `mpserverless.aliyuncs.com`
- 当前 `mpserverless.cn-hangzhou.aliyuncs.com` 在本机环境 TLS 握手失败，不再作为默认 endpoint
- 运行时最适合走 Node SDK
- `aliyun` CLI 更适合承担本机凭证 profile 与 `sts GetCallerIdentity`
- 若后续需要 Agent 远程控制，可再接 `aliyun mcp-proxy`
- 凭证与 `serverSecret` 都不应写入仓库
- 官方控制面 SDK 当前未暴露函数环境变量管理字段，`BLM_APP_ENV`、`BLM_ADMIN_*` 仍需通过控制台维护

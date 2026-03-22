#!/usr/bin/env node

const fs = require("fs");
const os = require("os");
const path = require("path");
const { execFileSync } = require("child_process");

const SDK = require("@alicloud/mpserverless20190615");
const Client = SDK.default;

const ACTION = process.argv[2] || "check";
const PROFILE = process.env.ALIYUN_PROFILE === undefined ? "bianlunmiao-emas" : process.env.ALIYUN_PROFILE;
const REGION = process.env.EMAS_REGION || "cn-hangzhou";
const ENDPOINT = process.env.EMAS_ENDPOINT || "mpserverless.aliyuncs.com";
const SECRET_KEYS = new Set([
  "accessKeyId",
  "accessKeySecret",
  "securityToken",
  "stsToken",
  "serverSecret",
  "apiKey",
  "privateKey",
  "ServerSecret",
  "ApiKey",
  "PrivateKey",
  "AccessKeyId",
  "AccessKeySecret",
  "SecurityToken",
  "StsToken",
]);

function usage() {
  console.error(`用法:
  bash .agent/skills/aliyun-emas-serverless-ops/scripts/emas_openapi.sh check
  bash .agent/skills/aliyun-emas-serverless-ops/scripts/emas_openapi.sh call <Operation> [--json '{"spaceId":"mp-xxx"}']
  bash .agent/skills/aliyun-emas-serverless-ops/scripts/emas_openapi.sh call <Operation> [--file /path/to/request.json]
  bash .agent/skills/aliyun-emas-serverless-ops/scripts/emas_openapi.sh call <Operation> [--ParamName value ...]

环境变量:
  ALIYUN_PROFILE  默认 bianlunmiao-emas；设为空字符串时改用环境变量凭证
  EMAS_REGION     默认 cn-hangzhou
  EMAS_ENDPOINT   默认 mpserverless.aliyuncs.com
`);
}

function fail(message, details) {
  console.error(`[emas-openapi] ${message}`);
  if (details) {
    console.error(details);
  }
  process.exit(1);
}

function loadProfileCredentials(profileName) {
  const configPath = path.join(os.homedir(), ".aliyun", "config.json");
  if (!fs.existsSync(configPath)) {
    fail(`未找到 aliyun CLI 配置文件: ${configPath}`);
  }
  const config = JSON.parse(fs.readFileSync(configPath, "utf8"));
  const profile = (config.profiles || []).find((item) => item.name === profileName);
  if (!profile) {
    fail(`未找到 aliyun profile: ${profileName}`);
  }
  if (!profile.access_key_id || !profile.access_key_secret) {
    fail(`profile ${profileName} 缺少 AK/SK`);
  }
  return {
    accessKeyId: profile.access_key_id,
    accessKeySecret: profile.access_key_secret,
    securityToken: profile.sts_token || undefined,
  };
}

function loadCredentials() {
  const envCreds = {
    accessKeyId: process.env.ALIYUN_ACCESS_KEY_ID || "",
    accessKeySecret: process.env.ALIYUN_ACCESS_KEY_SECRET || "",
    securityToken: process.env.ALIYUN_SECURITY_TOKEN || process.env.ALIYUN_STS_TOKEN || undefined,
  };
  if (envCreds.accessKeyId && envCreds.accessKeySecret) {
    return { ...envCreds, source: "env" };
  }
  if (PROFILE === "") {
    fail("ALIYUN_PROFILE 已显式置空，但环境变量中没有可用的 AK/SK");
  }
  return { ...loadProfileCredentials(PROFILE), source: `profile:${PROFILE}` };
}

function createClient() {
  const creds = loadCredentials();
  const client = new Client({
    accessKeyId: creds.accessKeyId,
    accessKeySecret: creds.accessKeySecret,
    securityToken: creds.securityToken,
    regionId: REGION,
    endpoint: ENDPOINT,
  });
  return { client, creds };
}

function redact(value) {
  if (Array.isArray(value)) {
    return value.map(redact);
  }
  if (value && typeof value === "object") {
    const output = {};
    for (const [key, inner] of Object.entries(value)) {
      output[key] = SECRET_KEYS.has(key) ? "<redacted>" : redact(inner);
    }
    return output;
  }
  return value;
}

function lowerFirst(value) {
  return value ? value[0].toLowerCase() + value.slice(1) : value;
}

function kebabToCamel(value) {
  return value.replace(/-([a-z])/g, (_, c) => c.toUpperCase());
}

function normalizeParamKey(rawKey) {
  const withoutPrefix = rawKey.replace(/^--/, "");
  if (withoutPrefix.includes("-")) {
    return kebabToCamel(withoutPrefix);
  }
  return lowerFirst(withoutPrefix);
}

function parseScalar(rawValue) {
  if (rawValue === undefined) {
    return true;
  }
  try {
    return JSON.parse(rawValue);
  } catch {
    return rawValue;
  }
}

function parseRequestArgs(argv) {
  let params = {};
  let i = 0;
  while (i < argv.length) {
    const arg = argv[i];
    if (arg === "--json") {
      params = { ...params, ...JSON.parse(argv[i + 1] || "{}") };
      i += 2;
      continue;
    }
    if (arg === "--file") {
      const payload = fs.readFileSync(path.resolve(argv[i + 1]), "utf8");
      params = { ...params, ...JSON.parse(payload) };
      i += 2;
      continue;
    }
    if (!arg.startsWith("--")) {
      fail(`无法解析参数: ${arg}`);
    }
    const key = normalizeParamKey(arg);
    const next = argv[i + 1];
    const consumesNext = next !== undefined && !next.startsWith("--");
    const value = consumesNext
      ? ((key === "body" || key === "Body") ? next : parseScalar(next))
      : true;
    params[key] = value;
    i += consumesNext ? 2 : 1;
  }
  return params;
}

function runStsIdentity() {
  if (!process.env.PATH || !PROFILE) {
    return null;
  }
  try {
    const args = ["sts", "GetCallerIdentity", "--profile", PROFILE];
    const output = execFileSync("aliyun", args, { encoding: "utf8", stdio: ["ignore", "pipe", "pipe"] });
    return JSON.parse(output);
  } catch (error) {
    return {
      warning: "aliyun sts GetCallerIdentity 调用失败",
      stderr: error.stderr ? String(error.stderr).trim() : undefined,
      status: error.status,
    };
  }
}

async function runCheck() {
  const { client, creds } = createClient();
  const identity = runStsIdentity();
  const request = new SDK.DescribeSpacesRequest({ pageNum: 0, pageSize: 20 });
  const summary = {
    credentialMode: creds.source,
    endpoint: ENDPOINT,
    region: REGION,
    identity,
  };
  console.log(JSON.stringify(redact(summary), null, 2));
  const resp = await client.describeSpaces(request);
  console.log(JSON.stringify(redact(resp.body || {}), null, 2));
}

async function runCall() {
  const operation = process.argv[3];
  if (!operation) {
    usage();
    process.exit(1);
  }
  const { client, creds } = createClient();
  const methodName = lowerFirst(operation);
  const requestClassName = `${operation}Request`;
  const RequestClass = SDK[requestClassName];
  if (typeof client[methodName] !== "function") {
    fail(`SDK 中不存在方法: ${methodName}`);
  }
  const params = parseRequestArgs(process.argv.slice(4));
  if ((operation === "RunDBCommand" || operation === "RunFunction")
    && params.body
    && typeof params.body !== "string") {
    params.body = JSON.stringify(params.body);
  }
  const request = RequestClass ? new RequestClass(params) : params;
  const resp = await client[methodName](request);
  const output = {
    credentialMode: creds.source,
    endpoint: ENDPOINT,
    region: REGION,
    operation,
    request: redact(params),
    response: redact(resp.body || {}),
  };
  console.log(JSON.stringify(output, null, 2));
}

async function main() {
  try {
    if (ACTION === "check") {
      await runCheck();
      return;
    }
    if (ACTION === "call") {
      await runCall();
      return;
    }
    usage();
    process.exit(1);
  } catch (error) {
    const payload = {
      action: ACTION,
      endpoint: ENDPOINT,
      region: REGION,
      errorName: error.name,
      message: error.message,
      data: redact(error.data || {}),
    };
    console.error(JSON.stringify(payload, null, 2));
    process.exit(1);
  }
}

main();

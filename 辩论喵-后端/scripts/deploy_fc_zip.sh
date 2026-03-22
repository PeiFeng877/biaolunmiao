#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ALIYUN_PROFILE="${ALIYUN_PROFILE:-bianlunmiao}"
FC_REGION="${FC_REGION:-cn-hangzhou}"
FC_FUNCTION_NAME="${FC_FUNCTION_NAME:-bianlunmiao-api-prod}"
FC_TRIGGER_NAME="${FC_TRIGGER_NAME:-defaultTrigger}"
FC_ENV_FILE="${FC_ENV_FILE:-${ROOT_DIR}/.env.fc.prod.local}"
FC_ZIP_PATH="${FC_ZIP_PATH:-${ROOT_DIR}/artifacts/fc/bianlunmiao-api.zip}"
FC_CODE_OSS_BUCKET="${FC_CODE_OSS_BUCKET:-bianlunmiao-assets-1917380129637610}"
FC_CODE_OSS_OBJECT="${FC_CODE_OSS_OBJECT:-fc/code/${FC_FUNCTION_NAME}/bianlunmiao-api-$(date +%Y%m%d%H%M%S).zip}"
FC_VPC_ID="${FC_VPC_ID:-}"
FC_VSWITCH_ID="${FC_VSWITCH_ID:-}"
FC_SECURITY_GROUP_ID="${FC_SECURITY_GROUP_ID:-}"
FC_ROLE_ARN="${FC_ROLE_ARN:-}"
FC_CPU="${FC_CPU:-1}"
FC_MEMORY_SIZE="${FC_MEMORY_SIZE:-1024}"
FC_TIMEOUT="${FC_TIMEOUT:-60}"
FC_INSTANCE_CONCURRENCY="${FC_INSTANCE_CONCURRENCY:-10}"
FC_LISTEN_PORT="${FC_LISTEN_PORT:-9000}"
FC_DESCRIPTION="${FC_DESCRIPTION:-辩论喵正式 FastAPI 后端}"

require() {
  command -v "$1" >/dev/null 2>&1 || {
    echo "missing required command: $1" >&2
    exit 1
  }
}

require aliyun
require jq
require python3

if [[ ! -f "${FC_ZIP_PATH}" ]]; then
  echo "FC zip artifact not found: ${FC_ZIP_PATH}" >&2
  exit 1
fi

if [[ ! -f "${FC_ENV_FILE}" ]]; then
  echo "FC env file not found: ${FC_ENV_FILE}" >&2
  exit 1
fi

env_json="$(
  python3 - "${FC_ENV_FILE}" <<'PY'
import json
import pathlib
import sys

env = {}
for line in pathlib.Path(sys.argv[1]).read_text(encoding="utf-8").splitlines():
    stripped = line.strip()
    if not stripped or stripped.startswith("#") or "=" not in stripped:
        continue
    key, value = stripped.split("=", 1)
    env[key.strip()] = value.strip().strip("'").strip('"')
print(json.dumps(env, ensure_ascii=False))
PY
)"

profile_json="$(aliyun configure get --profile "${ALIYUN_PROFILE}")"
export ALIBABA_CLOUD_ACCESS_KEY_ID="$(printf '%s' "${profile_json}" | jq -r '.access_key_id')"
export ALIBABA_CLOUD_ACCESS_KEY_SECRET="$(printf '%s' "${profile_json}" | jq -r '.access_key_secret')"
export ALIBABA_CLOUD_SECURITY_TOKEN="$(printf '%s' "${profile_json}" | jq -r '.sts_token')"

aliyun --profile "${ALIYUN_PROFILE}" oss cp \
  "${FC_ZIP_PATH}" \
  "oss://${FC_CODE_OSS_BUCKET}/${FC_CODE_OSS_OBJECT}" \
  --force >/dev/null

vpc_config='null'
if [[ -n "${FC_VPC_ID}" && -n "${FC_VSWITCH_ID}" && -n "${FC_SECURITY_GROUP_ID}" ]]; then
  vpc_config="$(jq -cn \
    --arg vpcId "${FC_VPC_ID}" \
    --arg vSwitchId "${FC_VSWITCH_ID}" \
    --arg securityGroupId "${FC_SECURITY_GROUP_ID}" \
    --arg role "${FC_ROLE_ARN}" \
    '{
      vpcId:$vpcId,
      vSwitchIds:[$vSwitchId],
      securityGroupId:$securityGroupId
    } + (if $role == "" then {} else {role:$role} end)'
  )"
fi

function_body="$(jq -cn \
  --arg functionName "${FC_FUNCTION_NAME}" \
  --arg description "${FC_DESCRIPTION}" \
  --arg runtime "custom.debian10" \
  --arg ossBucketName "${FC_CODE_OSS_BUCKET}" \
  --arg ossObjectName "${FC_CODE_OSS_OBJECT}" \
  --argjson cpu "${FC_CPU}" \
  --argjson memorySize "${FC_MEMORY_SIZE}" \
  --argjson timeout "${FC_TIMEOUT}" \
  --argjson instanceConcurrency "${FC_INSTANCE_CONCURRENCY}" \
  --argjson listenPort "${FC_LISTEN_PORT}" \
  --argjson environmentVariables "${env_json}" \
  --argjson vpcConfig "${vpc_config}" \
  '{
    functionName:$functionName,
    description:$description,
    runtime:$runtime,
    cpu:$cpu,
    memorySize:$memorySize,
    timeout:$timeout,
    diskSize:512,
    instanceConcurrency:$instanceConcurrency,
    internetAccess:true,
    environmentVariables:$environmentVariables,
    customRuntimeConfig:{
      command:["/code/bootstrap"],
      port:$listenPort
    },
    code:{
      ossBucketName:$ossBucketName,
      ossObjectName:$ossObjectName
    }
  } + (if $vpcConfig == null then {} else {vpcConfig:$vpcConfig} end)'
)"

trigger_config='{"authType":"anonymous","disableURLInternet":false,"methods":["GET","POST","PUT","DELETE","HEAD","OPTIONS"]}'
trigger_body="$(jq -cn \
  --arg triggerName "${FC_TRIGGER_NAME}" \
  --arg triggerType "http" \
  --arg description "public http trigger" \
  --arg triggerConfig "${trigger_config}" \
  '{triggerName:$triggerName,triggerType:$triggerType,description:$description,triggerConfig:$triggerConfig}'
)"

set +e
aliyun fc GET "/2023-03-30/functions/${FC_FUNCTION_NAME}" --region "${FC_REGION}" >/dev/null 2>&1
get_status=$?
set -e

if [[ ${get_status} -eq 0 ]]; then
  aliyun fc PUT "/2023-03-30/functions/${FC_FUNCTION_NAME}" --region "${FC_REGION}" --body "${function_body}" >/dev/null
else
  aliyun fc POST /2023-03-30/functions --region "${FC_REGION}" --body "${function_body}" >/dev/null
fi

set +e
aliyun fc GET "/2023-03-30/functions/${FC_FUNCTION_NAME}/triggers/${FC_TRIGGER_NAME}" --region "${FC_REGION}" >/dev/null 2>&1
trigger_status=$?
set -e

if [[ ${trigger_status} -eq 0 ]]; then
  aliyun fc PUT "/2023-03-30/functions/${FC_FUNCTION_NAME}/triggers/${FC_TRIGGER_NAME}" --region "${FC_REGION}" --body "${trigger_body}" >/dev/null
else
  aliyun fc POST "/2023-03-30/functions/${FC_FUNCTION_NAME}/triggers" --region "${FC_REGION}" --body "${trigger_body}" >/dev/null
fi

trigger_json="$(aliyun fc GET "/2023-03-30/functions/${FC_FUNCTION_NAME}/triggers/${FC_TRIGGER_NAME}" --region "${FC_REGION}")"
url_internet="$(printf '%s' "${trigger_json}" | jq -r '.httpTrigger.urlInternet')"

printf 'FC_FUNCTION_NAME=%s\n' "${FC_FUNCTION_NAME}"
printf 'FC_URL=%s\n' "${url_internet}"
printf 'FC_CODE_OSS=oss://%s/%s\n' "${FC_CODE_OSS_BUCKET}" "${FC_CODE_OSS_OBJECT}"

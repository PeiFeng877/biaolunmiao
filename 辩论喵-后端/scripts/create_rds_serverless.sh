#!/usr/bin/env bash

set -euo pipefail

ALIYUN_PROFILE="${ALIYUN_PROFILE:-bianlunmiao}"
RDS_REGION="${RDS_REGION:-cn-hangzhou}"
RDS_ZONE_ID="${RDS_ZONE_ID:-cn-hangzhou-i}"
RDS_INSTANCE_NAME="${RDS_INSTANCE_NAME:-bianlunmiao-pg-serverless}"
RDS_CLIENT_TOKEN="${RDS_CLIENT_TOKEN:-bianlunmiao-pg-serverless-cn-hangzhou-v1}"
RDS_READ_TIMEOUT="${RDS_READ_TIMEOUT:-300}"
RDS_CONNECT_TIMEOUT="${RDS_CONNECT_TIMEOUT:-30}"
RDS_VPC_ID="${RDS_VPC_ID:-vpc-bp1rzf2520zp404pcqwda}"
RDS_VSWITCH_ID="${RDS_VSWITCH_ID:-vsw-bp1jz9b75pfduexkzz3p8}"
RDS_SECURITY_IP_LIST="${RDS_SECURITY_IP_LIST:-172.30.16.0/20}"
RDS_DB_INSTANCE_CLASS="${RDS_DB_INSTANCE_CLASS:-pg.n2.serverless.1c}"
RDS_STORAGE_GB="${RDS_STORAGE_GB:-20}"
RDS_MAX_CAPACITY="${RDS_MAX_CAPACITY:-1}"
RDS_MIN_CAPACITY="${RDS_MIN_CAPACITY:-0.5}"
RDS_AUTO_PAUSE="${RDS_AUTO_PAUSE:-true}"
RDS_SWITCH_FORCE="${RDS_SWITCH_FORCE:-false}"
RDS_MASTER_USERNAME="${RDS_MASTER_USERNAME:-bianlunmiao_admin}"
RDS_MASTER_PASSWORD="${RDS_MASTER_PASSWORD:-}"
RDS_DATABASE_NAME="${RDS_DATABASE_NAME:-bianlunmiao}"
RDS_TIME_ZONE="${RDS_TIME_ZONE:-Asia/Shanghai}"

require() {
  command -v "$1" >/dev/null 2>&1 || {
    echo "missing required command: $1" >&2
    exit 1
  }
}

random_password() {
  python3 - <<'PY'
import secrets
alphabet = "ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz23456789!@#$%^&*()_+-="
print("".join(secrets.choice(alphabet) for _ in range(24)))
PY
}

require aliyun
require jq
require python3

if [[ -z "${RDS_MASTER_PASSWORD}" ]]; then
  RDS_MASTER_PASSWORD="$(random_password)"
fi

serverless_config="$(jq -cn \
  --argjson maxCapacity "${RDS_MAX_CAPACITY}" \
  --argjson minCapacity "${RDS_MIN_CAPACITY}" \
  --arg autoPause "${RDS_AUTO_PAUSE}" \
  --arg switchForce "${RDS_SWITCH_FORCE}" \
  '{MaxCapacity:$maxCapacity, MinCapacity:$minCapacity, AutoPause:($autoPause=="true"), SwitchForce:($switchForce=="true")}'
)"

create_json="$(
  aliyun --profile "${ALIYUN_PROFILE}" rds CreateDBInstance \
    --connect-timeout "${RDS_CONNECT_TIMEOUT}" \
    --read-timeout "${RDS_READ_TIMEOUT}" \
    --RegionId "${RDS_REGION}" \
    --Engine PostgreSQL \
    --EngineVersion 16.0 \
    --PayType Serverless \
    --Category serverless_basic \
    --DBInstanceClass "${RDS_DB_INSTANCE_CLASS}" \
    --DBInstanceStorage "${RDS_STORAGE_GB}" \
    --DBInstanceStorageType cloud_essd \
    --DBInstanceNetType Intranet \
    --InstanceNetworkType VPC \
    --ZoneId "${RDS_ZONE_ID}" \
    --VPCId "${RDS_VPC_ID}" \
    --VSwitchId "${RDS_VSWITCH_ID}" \
    --SecurityIPList "${RDS_SECURITY_IP_LIST}" \
    --ServerlessConfig "${serverless_config}" \
    --ClientToken "${RDS_CLIENT_TOKEN}" \
    --DBTimeZone "${RDS_TIME_ZONE}" \
    --DBInstanceDescription "${RDS_INSTANCE_NAME}" \
    --DeletionProtection true \
    --AutoPay true
)"

db_instance_id="$(printf '%s' "${create_json}" | jq -r '.DBInstanceId // .Data.DBInstanceId // empty')"
if [[ -z "${db_instance_id}" ]]; then
  echo "failed to create RDS instance" >&2
  printf '%s\n' "${create_json}" >&2
  exit 1
fi

echo "created RDS instance: ${db_instance_id}"

for _ in $(seq 1 60); do
  status="$(
    aliyun --profile "${ALIYUN_PROFILE}" rds DescribeDBInstanceAttribute \
      --connect-timeout "${RDS_CONNECT_TIMEOUT}" \
      --read-timeout "${RDS_READ_TIMEOUT}" \
      --RegionId "${RDS_REGION}" \
      --DBInstanceId "${db_instance_id}" \
      | jq -r '.Items.DBInstanceAttribute[0].DBInstanceStatus'
  )"
  if [[ "${status}" == "Running" ]]; then
    break
  fi
  sleep 10
done

aliyun --profile "${ALIYUN_PROFILE}" rds CreateAccount \
  --connect-timeout "${RDS_CONNECT_TIMEOUT}" \
  --read-timeout "${RDS_READ_TIMEOUT}" \
  --RegionId "${RDS_REGION}" \
  --DBInstanceId "${db_instance_id}" \
  --AccountName "${RDS_MASTER_USERNAME}" \
  --AccountPassword "${RDS_MASTER_PASSWORD}" \
  --AccountType Super >/dev/null

aliyun --profile "${ALIYUN_PROFILE}" rds CreateDatabase \
  --connect-timeout "${RDS_CONNECT_TIMEOUT}" \
  --read-timeout "${RDS_READ_TIMEOUT}" \
  --RegionId "${RDS_REGION}" \
  --DBInstanceId "${db_instance_id}" \
  --DBName "${RDS_DATABASE_NAME}" \
  --CharacterSetName UTF8 >/dev/null

connection_json="$(
  aliyun --profile "${ALIYUN_PROFILE}" rds DescribeDBInstanceNetInfo \
    --connect-timeout "${RDS_CONNECT_TIMEOUT}" \
    --read-timeout "${RDS_READ_TIMEOUT}" \
    --RegionId "${RDS_REGION}" \
    --DBInstanceId "${db_instance_id}"
)"
private_host="$(printf '%s' "${connection_json}" | jq -r '.DBInstanceNetInfos.DBInstanceNetInfo[] | select(.IPType=="Private") | .ConnectionString' | head -n1)"

printf 'DB_INSTANCE_ID=%s\n' "${db_instance_id}"
printf 'DATABASE_URL=postgresql+psycopg2://%s:%s@%s:5432/%s\n' \
  "${RDS_MASTER_USERNAME}" \
  "${RDS_MASTER_PASSWORD}" \
  "${private_host}" \
  "${RDS_DATABASE_NAME}"

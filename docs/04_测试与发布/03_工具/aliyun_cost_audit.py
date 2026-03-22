#!/usr/bin/env python3
"""Audit bianlunmiao Aliyun resources and costs via aliyun CLI."""

from __future__ import annotations

import argparse
import datetime as dt
import json
import os
import subprocess
import sys
import time
from dataclasses import dataclass
from typing import Any, Callable


def run_aliyun(profile: str, args: list[str], retries: int = 3) -> dict[str, Any]:
    command = ["aliyun", "--profile", profile, *args]
    last_error = "aliyun command failed"
    for attempt in range(1, retries + 1):
        completed = subprocess.run(command, capture_output=True, text=True, check=False)
        if completed.returncode == 0:
            return json.loads(completed.stdout)
        last_error = completed.stderr.strip() or completed.stdout.strip() or last_error
        if attempt < retries:
            time.sleep(attempt)
    raise RuntimeError(last_error)


def extract_items(payload: dict[str, Any]) -> list[dict[str, Any]]:
    items = payload.get("Data", {}).get("Items", {}).get("Item", [])
    return items if isinstance(items, list) else [items]


def day_before() -> dt.date:
    return dt.date.today() - dt.timedelta(days=1)


@dataclass(frozen=True)
class ServiceDef:
    service: str
    resource_id: str
    env: str
    billing_model: str
    purpose: str
    can_save: bool
    recommended_action: str
    matcher: Callable[[dict[str, Any]], bool] | None = None
    product_code: str | None = None


SERVICES = [
    ServiceDef(
        service="FC prod",
        resource_id="bianlunmiao-api-prod",
        env="prod",
        billing_model="PayAsYouGo",
        purpose="正式后端运行时（FC 默认域名）",
        can_save=False,
        recommended_action="低流量阶段按调用量计费，关注函数调用与日志写入。",
        matcher=lambda row: row.get("InstanceID") in {"bianlunmiao-api-prod", "bianlunmiao-api-prod;cn-hangzhou"},
    ),
    ServiceDef(
        service="RDS PostgreSQL Serverless",
        resource_id="pgm-bp10h4wa78jnh7h5",
        env="prod",
        billing_model="PayAsYouGo",
        purpose="正式数据库（AutoPause）",
        can_save=False,
        recommended_action="保持最小 Serverless 配置，按需关注休眠与唤醒频率。",
        matcher=lambda row: row.get("InstanceID", "").startswith("pgm-bp10h4wa78jnh7h5;"),
    ),
    ServiceDef(
        service="RDS legacy main",
        resource_id="pgm-bp1v5t851p7rtl93",
        env="legacy",
        billing_model="PayAsYouGo",
        purpose="旧生产数据库（待释放时才应保留）",
        can_save=True,
        recommended_action="若仍出现在审计结果，说明旧库尚未释放，应尽快清理。",
        matcher=lambda row: row.get("InstanceID", "").startswith("pgm-bp1v5t851p7rtl93;"),
    ),
    ServiceDef(
        service="EMAS legacy prod",
        resource_id="mp-ac3c9a37-fb9e-4486-9496-73fe4c034bd3",
        env="legacy",
        billing_model="PayAsYouGo",
        purpose="历史 EMAS 正式空间",
        can_save=True,
        recommended_action="若仍有费用，检查删除是否完成及账单滞后。",
        matcher=lambda row: row.get("InstanceID") == "mp-ac3c9a37-fb9e-4486-9496-73fe4c034bd3",
    ),
    ServiceDef(
        service="EMAS legacy stg",
        resource_id="mp-f66871d8-f47d-4051-a793-86c41f920aa1",
        env="legacy",
        billing_model="PayAsYouGo",
        purpose="历史 EMAS 测试空间",
        can_save=True,
        recommended_action="若仍有费用，检查删除是否完成及账单滞后。",
        matcher=lambda row: row.get("InstanceID") == "mp-f66871d8-f47d-4051-a793-86c41f920aa1",
    ),
    ServiceDef(
        service="ECS legacy HTTPS 入口",
        resource_id="i-bp1gu52ini5t0l9maibb",
        env="legacy",
        billing_model="Subscription",
        purpose="历史 HTTPS 反代与备案实例",
        can_save=True,
        recommended_action="包年包月实例当前是沉没成本；若确认不再使用，可停机并评估到期不续费。",
        product_code="ecs",
    ),
    ServiceDef(
        service="OSS",
        resource_id="bianlunmiao-assets-1917380129637610",
        env="shared",
        billing_model="PayAsYouGo",
        purpose="正式图片与静态对象存储",
        can_save=False,
        recommended_action="保持现状。",
        matcher=lambda row: row.get("ProductCode") == "oss",
    ),
    ServiceDef(
        service="SLS",
        resource_id="aliyun-product-data-1917380129637610-cn-hangzhou:sae_event",
        env="shared",
        billing_model="PayAsYouGo",
        purpose="日志写入",
        can_save=False,
        recommended_action="保持现状。",
        matcher=lambda row: row.get("ProductCode") == "sls",
    ),
]


def period_days(item: dict[str, Any]) -> float:
    period = float(item.get("ServicePeriod", 0) or 0)
    unit = item.get("ServicePeriodUnit")
    if unit == "秒":
        return period / 86400
    if unit == "天":
        return period
    if unit == "月":
        return period * 30
    if unit == "年":
        return period * 365
    raise RuntimeError(f"Unsupported service period unit: {unit}")


def month_candidates(anchor: dt.date, max_months: int = 12) -> list[str]:
    result: list[str] = []
    year = anchor.year
    month = anchor.month
    for _ in range(max_months):
        result.append(f"{year:04d}-{month:02d}")
        month -= 1
        if month <= 0:
            month = 12
            year -= 1
    return result


def query_daily_items(profile: str, billing_date: dt.date) -> list[dict[str, Any]]:
    payload = run_aliyun(
        profile,
        [
            "bssopenapi",
            "QueryInstanceBill",
            "--BillingCycle",
            billing_date.strftime("%Y-%m"),
            "--Granularity",
            "DAILY",
            "--BillingDate",
            billing_date.isoformat(),
            "--PageNum",
            "1",
            "--PageSize",
            "300",
            "--IsHideZeroCharge",
            "true",
        ],
    )
    return extract_items(payload)


def query_month_overview(profile: str, billing_cycle: str) -> list[dict[str, Any]]:
    payload = run_aliyun(profile, ["bssopenapi", "QueryBillOverview", "--BillingCycle", billing_cycle])
    return extract_items(payload)


def query_subscription_item(profile: str, anchor: dt.date, service: ServiceDef) -> dict[str, Any]:
    if service.product_code is None:
        raise RuntimeError("Missing product code for subscription service")
    for cycle in month_candidates(anchor):
        payload = run_aliyun(
            profile,
            [
                "bssopenapi",
                "QueryInstanceBill",
                "--BillingCycle",
                cycle,
                "--ProductCode",
                service.product_code,
                "--PageNum",
                "1",
                "--PageSize",
                "300",
                "--IsHideZeroCharge",
                "true",
            ],
        )
        for row in extract_items(payload):
            if row.get("SubscriptionType") != "Subscription":
                continue
            if service.product_code == "ecs" and row.get("InstanceID") != service.resource_id:
                continue
            return row
    raise RuntimeError(f"Subscription order not found for {service.service}")


def round6(value: float) -> float:
    return float(f"{value:.6f}")


def build_report(profile: str, billing_date: dt.date) -> dict[str, Any]:
    daily_items = query_daily_items(profile, billing_date)
    overview_items = query_month_overview(profile, billing_date.strftime("%Y-%m"))

    services: list[dict[str, Any]] = []
    payg_daily = 0.0
    prepaid_daily = 0.0

    for service in SERVICES:
        if service.billing_model == "PayAsYouGo":
            matches = [row for row in daily_items if service.matcher and service.matcher(row)]
            daily_cost = sum(float(row.get("PretaxAmount", 0) or 0) for row in matches)
            payg_daily += daily_cost
        else:
            order = query_subscription_item(profile, billing_date, service)
            daily_cost = float(order.get("PretaxAmount", 0) or 0) / period_days(order)
            prepaid_daily += daily_cost

        services.append(
            {
                "service": service.service,
                "resource_id": service.resource_id,
                "env": service.env,
                "billing_model": service.billing_model,
                "daily_cost": round6(daily_cost),
                "purpose": service.purpose,
                "can_save": service.can_save,
                "recommended_action": service.recommended_action,
            }
        )

    mtd_payg = 0.0
    for row in overview_items:
        if row.get("SubscriptionType") == "PayAsYouGo" and row.get("ProductCode") in {"sae", "slb", "rds", "oss", "sls"}:
            mtd_payg += float(row.get("PretaxAmount", 0) or 0)

    checks = [
        query_check_sae(profile),
        query_check_clb(profile),
        query_check_rds(profile),
        query_check_emas(profile),
        query_check_redis(profile),
        query_check_dns(profile),
    ]

    return {
        "profile": profile,
        "billing_date": billing_date.isoformat(),
        "summary": {
            "payg_daily_total": round6(payg_daily),
            "prepaid_daily_total": round6(prepaid_daily),
            "daily_total": round6(payg_daily + prepaid_daily),
            "mtd_payg_total": round6(mtd_payg),
        },
        "checks": checks,
        "services": services,
    }


def query_check_sae(profile: str) -> dict[str, Any]:
    payload = run_aliyun(
        profile,
        ["--endpoint", "sae.cn-hangzhou.aliyuncs.com", "sae", "ListApplications", "--RegionId", "cn-hangzhou"],
    )
    apps = payload.get("Data", {}).get("Applications", [])
    names = sorted(app.get("AppName") for app in apps)
    passed = names == []
    return {"name": "SAE 已清空", "passed": passed, "detail": f"发现应用: {names}"}


def query_check_clb(profile: str) -> dict[str, Any]:
    payload = run_aliyun(profile, ["slb", "DescribeLoadBalancers", "--RegionId", "cn-hangzhou"])
    lbs = payload.get("LoadBalancers", {}).get("LoadBalancer", [])
    ips = sorted(lb.get("Address") for lb in lbs if lb.get("Address"))
    passed = ips == []
    return {"name": "CLB 已清空", "passed": passed, "detail": f"发现公网地址: {ips}"}


def query_check_rds(profile: str) -> dict[str, Any]:
    payload = run_aliyun(profile, ["rds", "DescribeDBInstances", "--RegionId", "cn-hangzhou", "--Engine", "PostgreSQL"])
    items = payload.get("Items", {}).get("DBInstance", [])
    ids = [item.get("DBInstanceId") for item in items]
    passed = ids == ["pgm-bp10h4wa78jnh7h5"]
    return {"name": "RDS 单实例（Serverless）", "passed": passed, "detail": f"发现 RDS: {ids}"}


def query_check_emas(profile: str) -> dict[str, Any]:
    command = [
        "bash",
        ".agent/skills/aliyun-emas-serverless-ops/scripts/emas_openapi.sh",
        "call",
        "DescribeSpaces",
        "--json",
        '{"pageNum":0,"pageSize":20}',
    ]
    completed = subprocess.run(
        command,
        capture_output=True,
        text=True,
        check=False,
        env={**os.environ, "ALIYUN_PROFILE": profile},
    )
    if completed.returncode != 0:
        return {"name": "EMAS 已清空", "passed": False, "detail": completed.stderr.strip() or completed.stdout.strip()}
    payload = json.loads(completed.stdout)
    spaces = payload.get("response", {}).get("spaces", [])
    active = sorted(space.get("spaceId") for space in spaces if space.get("specCode") != "FREE")
    passed = active == []
    return {"name": "EMAS 按量空间已清空", "passed": passed, "detail": f"发现按量 space: {active}"}


def query_check_redis(profile: str) -> dict[str, Any]:
    payload = run_aliyun(profile, ["r-kvstore", "DescribeInstances", "--RegionId", "cn-hangzhou"])
    items = payload.get("Instances", {}).get("KVStoreInstance", [])
    return {"name": "Redis 未启用", "passed": len(items) == 0, "detail": f"Redis/Tair 实例数: {len(items)}"}


def query_check_dns(profile: str) -> dict[str, Any]:
    payload = run_aliyun(
        profile,
        ["alidns", "DescribeDomainRecords", "--DomainName", "bianlunmiao.top", "--PageSize", "100"],
    )
    records = payload.get("DomainRecords", {}).get("Record", [])
    mapping = {record.get("RR"): record.get("Value") for record in records}
    passed = True
    detail = f"当前记录: api={mapping.get('api')}, api-stg={mapping.get('api-stg')}"
    return {"name": "DNS 停放状态", "passed": passed, "detail": detail}


def to_markdown(report: dict[str, Any]) -> str:
    lines: list[str] = []
    lines.append("# 辩论喵阿里云资源与成本审计")
    lines.append("")
    lines.append(f"- Profile: `{report['profile']}`")
    lines.append(f"- 成本基准日: `{report['billing_date']}`")
    lines.append(f"- 月内累计口径: `{report['billing_date'][:7]}`")
    lines.append("")
    lines.append("## 资源清单")
    lines.append("| 服务 | 资源 ID | 环境 | 计费方式 | 日成本(元) | 作用 | 可节省 | 建议动作 |")
    lines.append("|---|---|---|---|---:|---|---|---|")
    for row in report["services"]:
        lines.append(
            f"| {row['service']} | {row['resource_id']} | {row['env']} | {row['billing_model']} | {row['daily_cost']:.6f} | {row['purpose']} | {'是' if row['can_save'] else '否'} | {row['recommended_action']} |"
        )
    lines.append("")
    lines.append("## 成本汇总")
    lines.append(f"- 稳态按量日成本: `{report['summary']['payg_daily_total']:.6f}` 元/天")
    lines.append(f"- 包年包月日摊销: `{report['summary']['prepaid_daily_total']:.6f}` 元/天")
    lines.append(f"- 稳态总日成本: `{report['summary']['daily_total']:.6f}` 元/天")
    lines.append(f"- 当月按量累计: `{report['summary']['mtd_payg_total']:.2f}` 元")
    lines.append("")
    lines.append("## 校验结果")
    for check in report["checks"]:
        lines.append(f"- `{'PASS' if check['passed'] else 'FAIL'}` {check['name']}: {check['detail']}")
    return "\n".join(lines)


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Audit bianlunmiao Aliyun resources and costs.")
    parser.add_argument("--profile", default="bianlunmiao", help="aliyun profile")
    parser.add_argument("--billing-date", default=day_before().isoformat(), help="YYYY-MM-DD")
    parser.add_argument("--format", choices=["markdown", "json"], default="markdown")
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    billing_date = dt.date.fromisoformat(args.billing_date)
    try:
        report = build_report(args.profile, billing_date)
    except Exception as exc:
        print(f"ERROR: {exc}", file=sys.stderr)
        return 1
    if args.format == "json":
        print(json.dumps(report, ensure_ascii=False, indent=2))
    else:
        print(to_markdown(report))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

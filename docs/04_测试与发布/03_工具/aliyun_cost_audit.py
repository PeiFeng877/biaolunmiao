#!/usr/bin/env python3
"""Audit bianlunmiao Aliyun resources and costs via aliyun CLI."""

from __future__ import annotations

import argparse
import datetime as dt
import json
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
        service="SAE prod",
        resource_id="b8561560-2980-4443-87ce-32d3d19ee701",
        env="prod",
        billing_model="PayAsYouGo",
        purpose="生产后端应用运行时",
        can_save=True,
        recommended_action="如收敛生产入口，可与 prod CLB 一并评估。",
        matcher=lambda row: row.get("InstanceID") == "b8561560-2980-4443-87ce-32d3d19ee701",
    ),
    ServiceDef(
        service="SAE stg",
        resource_id="9922a4c5-70a4-4452-b5c4-b038bb7c1cd7",
        env="stg",
        billing_model="PayAsYouGo",
        purpose="测试与联调后端环境",
        can_save=True,
        recommended_action="不用联调时关闭常驻。",
        matcher=lambda row: row.get("InstanceID") == "9922a4c5-70a4-4452-b5c4-b038bb7c1cd7",
    ),
    ServiceDef(
        service="CLB prod",
        resource_id="lb-bp11ko0r89ad8252el92z",
        env="prod",
        billing_model="PayAsYouGo",
        purpose="生产 SAE 公网入口",
        can_save=True,
        recommended_action="与生产入口架构调整联动优化。",
        matcher=lambda row: row.get("InstanceID") == "lb-bp11ko0r89ad8252el92z",
    ),
    ServiceDef(
        service="CLB stg",
        resource_id="lb-bp10eacwg0q6itc92xp1g",
        env="stg",
        billing_model="PayAsYouGo",
        purpose="测试 SAE 公网入口",
        can_save=True,
        recommended_action="与 stg SAE 一起按需启停。",
        matcher=lambda row: row.get("InstanceID") == "lb-bp10eacwg0q6itc92xp1g",
    ),
    ServiceDef(
        service="RDS PostgreSQL",
        resource_id="pgm-bp1v5t851p7rtl93",
        env="shared",
        billing_model="PayAsYouGo",
        purpose="生产与测试共享数据库",
        can_save=True,
        recommended_action="评估包年包月或更低规格。",
        matcher=lambda row: row.get("InstanceID", "").startswith("pgm-bp1v5t851p7rtl93;"),
    ),
    ServiceDef(
        service="ECS HTTPS 入口",
        resource_id="i-bp1gu52ini5t0l9maibb",
        env="infra",
        billing_model="Subscription",
        purpose="生产域名 HTTPS 反代与备案实例",
        can_save=True,
        recommended_action="若入口收敛到负载均衡可移除。",
        product_code="ecs",
    ),
    ServiceDef(
        service="OSS",
        resource_id="bianlunmiao-assets-1917380129637610",
        env="shared",
        billing_model="PayAsYouGo",
        purpose="图片与静态对象存储",
        can_save=False,
        recommended_action="保持现状。",
        matcher=lambda row: row.get("ProductCode") == "oss",
    ),
    ServiceDef(
        service="SLS",
        resource_id="aliyun-product-data-1917380129637610-cn-hangzhou:sae_event",
        env="shared",
        billing_model="PayAsYouGo",
        purpose="SAE 日志写入",
        can_save=False,
        recommended_action="保持现状。",
        matcher=lambda row: row.get("ProductCode") == "sls" and "sae_event" in row.get("InstanceID", ""),
    ),
    ServiceDef(
        service="域名 bianlunmiao.top",
        resource_id="bianlunmiao.top",
        env="infra",
        billing_model="Subscription",
        purpose="正式域名资产",
        can_save=False,
        recommended_action="保持现状。",
        product_code="domain",
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
    passed = names == ["bianlunmiao-backend-prod", "bianlunmiao-backend-stg"]
    return {"name": "SAE 双环境", "passed": passed, "detail": f"发现应用: {names}"}


def query_check_clb(profile: str) -> dict[str, Any]:
    payload = run_aliyun(profile, ["slb", "DescribeLoadBalancers", "--RegionId", "cn-hangzhou"])
    lbs = payload.get("LoadBalancers", {}).get("LoadBalancer", [])
    ips = sorted(lb.get("Address") for lb in lbs if lb.get("Address"))
    passed = "120.55.115.147" in ips and "121.43.226.231" in ips
    return {"name": "CLB 双入口", "passed": passed, "detail": f"发现公网地址: {ips}"}


def query_check_rds(profile: str) -> dict[str, Any]:
    payload = run_aliyun(profile, ["rds", "DescribeDBInstances", "--RegionId", "cn-hangzhou"])
    items = payload.get("Items", {}).get("DBInstance", [])
    ids = [item.get("DBInstanceId") for item in items]
    passed = ids == ["pgm-bp1v5t851p7rtl93"]
    return {"name": "RDS 单实例", "passed": passed, "detail": f"发现 RDS: {ids}"}


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
    passed = mapping.get("api") == "47.110.70.49" and mapping.get("api-stg") == "120.55.115.147"
    detail = f"当前记录: api={mapping.get('api')}, api-stg={mapping.get('api-stg')}"
    return {"name": "DNS 解析", "passed": passed, "detail": detail}


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

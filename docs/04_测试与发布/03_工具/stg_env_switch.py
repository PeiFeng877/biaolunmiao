#!/usr/bin/env python3
"""Probe whether the retired legacy staging stack still exists."""

from __future__ import annotations

import argparse
import json
import subprocess
import sys
import time
import urllib.error
import urllib.request
from typing import Any


STG_APP_ID = "9922a4c5-70a4-4452-b5c4-b038bb7c1cd7"
STG_CLB_ID = "lb-bp10eacwg0q6itc92xp1g"
STG_LISTENER_PORT = "80"
STG_LISTENER_PROTOCOL = "tcp"
STG_HEALTH_URL = "http://120.55.115.147/healthz"


class LegacyStgRetiredError(RuntimeError):
    """Raised when the legacy staging stack has been deleted."""


def run_aliyun(profile: str, args: list[str], retries: int = 3) -> dict[str, Any]:
    command = ["aliyun", "--profile", profile, *args]
    last_error = "aliyun command failed"
    for attempt in range(1, retries + 1):
        result = subprocess.run(command, capture_output=True, text=True, check=False)
        if result.returncode == 0:
            text = result.stdout.strip()
            return json.loads(text) if text else {}
        last_error = result.stderr.strip() or result.stdout.strip() or last_error
        if attempt < retries:
            time.sleep(attempt)
    raise RuntimeError(last_error)


def app_status(profile: str) -> dict[str, Any]:
    try:
        payload = run_aliyun(
            profile,
            [
                "--endpoint",
                "sae.cn-hangzhou.aliyuncs.com",
                "sae",
                "DescribeApplicationStatus",
                "--AppId",
                STG_APP_ID,
            ],
        )
    except RuntimeError as exc:
        if "InvalidAppId.NotFound" in str(exc):
            raise LegacyStgRetiredError(f"旧 stg SAE 应用已删除: {STG_APP_ID}") from exc
        raise
    return payload.get("Data", {})


def clb_status(profile: str, region: str) -> dict[str, Any]:
    payload = run_aliyun(
        profile,
        ["slb", "DescribeLoadBalancers", "--RegionId", region, "--LoadBalancerId", STG_CLB_ID],
    )
    items = payload.get("LoadBalancers", {}).get("LoadBalancer", [])
    if not items:
        raise LegacyStgRetiredError(f"旧 stg CLB 已删除: {STG_CLB_ID}")
    return items[0]


def listener_status(profile: str, region: str) -> dict[str, Any]:
    payload = run_aliyun(
        profile,
        [
            "slb",
            "DescribeLoadBalancerTCPListenerAttribute",
            "--RegionId",
            region,
            "--LoadBalancerId",
            STG_CLB_ID,
            "--ListenerPort",
            STG_LISTENER_PORT,
        ],
    )
    return payload


def http_health(timeout_seconds: float = 3.0) -> dict[str, Any]:
    req = urllib.request.Request(STG_HEALTH_URL, method="GET")
    try:
        with urllib.request.urlopen(req, timeout=timeout_seconds) as resp:
            body = resp.read().decode("utf-8", errors="replace")
            return {"ok": resp.status == 200, "status": resp.status, "body": body[:300]}
    except urllib.error.HTTPError as exc:
        return {"ok": False, "status": exc.code, "body": str(exc)}
    except Exception as exc:  # noqa: BLE001
        return {"ok": False, "status": None, "body": str(exc)}


def wait_until(timeout: int, interval: int, check, expected: str, label: str) -> None:
    deadline = time.time() + timeout
    while time.time() < deadline:
        current = check()
        if current == expected:
            return
        time.sleep(interval)
    raise RuntimeError(f"Timeout waiting {label}: expected {expected}")


def wait_condition(timeout: int, interval: int, check, predicate, label: str) -> None:
    deadline = time.time() + timeout
    while time.time() < deadline:
        current = check()
        if predicate(current):
            return
        time.sleep(interval)
    raise RuntimeError(f"Timeout waiting {label}")


def ensure_retired(action: str) -> None:
    raise LegacyStgRetiredError(f"旧 stg 资源已退役，仅支持 status 探针；不再允许执行 `{action}`。")


def build_status(profile: str, region: str) -> dict[str, Any]:
    try:
        app = app_status(profile)
        lb = clb_status(profile, region)
        listener = listener_status(profile, region)
        health = http_health()
    except LegacyStgRetiredError as exc:
        return {
            "legacy_stg": {
                "retired": True,
                "message": str(exc),
                "app_id": STG_APP_ID,
                "load_balancer_id": STG_CLB_ID,
            }
        }
    return {
        "sae": {
            "app_id": STG_APP_ID,
            "current_status": app.get("CurrentStatus"),
            "running_instances": app.get("RunningInstances"),
            "last_change_order_status": app.get("LastChangeOrderStatus"),
        },
        "clb": {
            "load_balancer_id": STG_CLB_ID,
            "status": lb.get("LoadBalancerStatus"),
            "address": lb.get("Address"),
        },
        "listener": {
            "port": STG_LISTENER_PORT,
            "protocol": STG_LISTENER_PROTOCOL,
            "status": listener.get("Status"),
            "vserver_group_id": listener.get("VServerGroupId"),
        },
        "healthz": health,
    }


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Probe the retired bianlunmiao legacy staging environment.")
    parser.add_argument("action", choices=["on", "off", "status"])
    parser.add_argument("--profile", default="bianlunmiao")
    parser.add_argument("--region", default="cn-hangzhou")
    parser.add_argument("--wait-seconds", type=int, default=300)
    parser.add_argument("--json", action="store_true", help="print status as JSON")
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    try:
        status = build_status(args.profile, args.region)
        if status.get("legacy_stg", {}).get("retired"):
            if args.action != "status":
                ensure_retired(args.action)
        elif args.action != "status":
            ensure_retired(args.action)
    except Exception as exc:
        print(f"ERROR: {exc}", file=sys.stderr)
        return 1

    if args.json:
        print(json.dumps(status, ensure_ascii=False, indent=2))
    else:
        print(f"SAE: {status['sae']['current_status']} (running={status['sae']['running_instances']})")
        print(f"CLB: {status['clb']['status']} @ {status['clb']['address']}")
        print(f"Listener: {status['listener']['protocol']}:{status['listener']['port']} -> {status['listener']['status']}")
        print(f"Healthz: ok={status['healthz']['ok']} status={status['healthz']['status']}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

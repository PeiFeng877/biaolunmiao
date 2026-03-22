import random
from datetime import datetime

from app.core.time import UTC


def now_utc() -> datetime:
    return datetime.now(UTC)


def generate_public_id(prefix: str = "") -> str:
    return f"{prefix}{random.randint(100000, 999999)}"


def match_positions(fmt: str) -> list[str]:
    table = {
        "1v1": ["一辩"],
        "2v2": ["一辩", "二辩"],
        "3v3": ["一辩", "二辩", "三辩"],
        "4v4": ["一辩", "二辩", "三辩", "四辩"],
    }
    return table.get(fmt, table["3v3"])

from collections.abc import Sequence
from typing import Generic, TypeVar

from pydantic import BaseModel

T = TypeVar("T")


class CursorPage(BaseModel, Generic[T]):
    items: list[T]
    nextCursor: str | None = None


def paginate(items: Sequence[T], cursor: str | None, limit: int) -> tuple[list[T], str | None]:
    start = int(cursor or "0")
    end = start + limit
    page_items = list(items[start:end])
    next_cursor = str(end) if end < len(items) else None
    return page_items, next_cursor

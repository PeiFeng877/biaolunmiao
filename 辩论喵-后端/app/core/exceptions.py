from dataclasses import dataclass
from typing import Any

from app.core.error_codes import ErrorCode


@dataclass(slots=True)
class AppException(Exception):
    code: ErrorCode
    message: str
    status_code: int
    details: dict[str, Any] | None = None

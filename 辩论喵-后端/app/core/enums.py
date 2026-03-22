from enum import Enum

try:
    from enum import StrEnum
except ImportError:  # pragma: no cover - Python 3.10 fallback for FC runtime
    class StrEnum(str, Enum):  # noqa: UP042
        pass

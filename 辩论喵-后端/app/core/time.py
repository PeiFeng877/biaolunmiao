from datetime import timezone

try:
    from datetime import UTC
except ImportError:  # pragma: no cover - Python 3.10 fallback for FC runtime
    UTC = timezone.utc  # noqa: UP017

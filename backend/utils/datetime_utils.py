"""Consistent local timestamps for ExamGuard (isoformat on API responses)."""

from datetime import datetime


def now() -> datetime:
    return datetime.now()


def now_iso() -> str:
    return datetime.now().isoformat()

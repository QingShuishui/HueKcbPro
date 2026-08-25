import os
import sys
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
if str(ROOT) not in sys.path:
    sys.path.insert(0, str(ROOT))

os.environ.setdefault("APP_ENV", "test")
os.environ.setdefault("DATABASE_URL", "sqlite+pysqlite:///:memory:")
os.environ.setdefault("REDIS_URL", "redis://localhost:6379/0")
os.environ.setdefault(
    "CREDENTIAL_ENCRYPTION_KEY",
    "MDEyMzQ1Njc4OWFiY2RlZjAxMjM0NTY3ODlhYmNkZWY=",
)
os.environ.setdefault("JWT_SECRET", "test-secret")

import app.models  # noqa: E402,F401
from app.core.db import SessionLocal, engine  # noqa: E402
from app.models.base import Base  # noqa: E402
import pytest  # noqa: E402


@pytest.fixture(autouse=True)
def reset_db():
    from app.modules.calendar.service import clear_academic_calendar_cache

    clear_academic_calendar_cache()
    Base.metadata.drop_all(engine)
    Base.metadata.create_all(engine)
    yield
    clear_academic_calendar_cache()
    SessionLocal.remove() if hasattr(SessionLocal, "remove") else None

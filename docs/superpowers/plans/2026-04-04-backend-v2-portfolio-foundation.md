# Backend V2 Portfolio Foundation Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build `backend_v2/` as the new FastAPI backend that authenticates users with academic credentials, stores encrypted bindings, serves cached schedules, runs background refresh jobs, and exposes the Android update API.

**Architecture:** The new backend is a modular monolith under `backend_v2/`. FastAPI serves versioned APIs, PostgreSQL stores users, bindings, schedule snapshots, and refresh tokens, Redis caches current schedule payloads and backs Celery, and `HUEConnector` isolates all school-specific scraping and parsing logic. The API always prefers cache reads and uses stale-while-revalidate for refreshes.

**Tech Stack:** Python 3.13, FastAPI, Pydantic Settings, SQLAlchemy 2, Alembic, PostgreSQL, Redis, Celery, Pytest, httpx, cryptography, BeautifulSoup, `ddddocr`, Sentry, Docker Compose

---

### Task 1: Scaffold `backend_v2` and prove health endpoints

**Files:**
- Create: `backend_v2/pyproject.toml`
- Create: `backend_v2/.env.example`
- Create: `backend_v2/app/__init__.py`
- Create: `backend_v2/app/main.py`
- Create: `backend_v2/app/core/settings.py`
- Create: `backend_v2/tests/conftest.py`
- Create: `backend_v2/tests/test_health.py`

- [ ] **Step 1: Write the failing test**

```python
# backend_v2/tests/test_health.py
from fastapi.testclient import TestClient

from app.main import create_app


def test_live_healthcheck_returns_ok():
    client = TestClient(create_app())

    response = client.get("/health/live")

    assert response.status_code == 200
    assert response.json() == {"status": "ok"}


def test_ready_healthcheck_returns_ok_when_dependencies_are_stubbed():
    client = TestClient(create_app())

    response = client.get("/health/ready")

    assert response.status_code == 200
    assert response.json()["status"] == "ready"
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd backend_v2 && pytest tests/test_health.py -q`
Expected: FAIL because `app.main` and `create_app()` do not exist yet.

- [ ] **Step 3: Write minimal implementation**

```toml
# backend_v2/pyproject.toml
[project]
name = "kcb-backend-v2"
version = "0.1.0"
requires-python = ">=3.13"
dependencies = [
  "fastapi>=0.116.0",
  "uvicorn[standard]>=0.35.0",
  "pydantic-settings>=2.10.0",
  "sqlalchemy>=2.0.43",
  "alembic>=1.16.0",
  "psycopg[binary]>=3.2.0",
  "redis>=6.4.0",
  "celery>=5.5.0",
  "httpx>=0.28.0",
  "cryptography>=45.0.0",
  "beautifulsoup4>=4.13.0",
  "lxml>=6.0.0",
  "requests>=2.32.0",
  "ddddocr>=1.5.6",
  "sentry-sdk[fastapi]>=2.35.0",
  "python-multipart>=0.0.20",
]

[project.optional-dependencies]
dev = [
  "pytest>=8.4.0",
  "pytest-cov>=6.2.0",
]
```

```python
# backend_v2/app/core/settings.py
from functools import lru_cache

from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    model_config = SettingsConfigDict(env_file=".env", extra="ignore")

    app_env: str = "development"
    app_name: str = "kcb-backend-v2"
    api_prefix: str = "/api/v1"
    database_url: str = "postgresql+psycopg://postgres:postgres@localhost:5432/kcb"
    redis_url: str = "redis://localhost:6379/0"
    sentry_dsn: str = ""


@lru_cache
def get_settings() -> Settings:
    return Settings()
```

```python
# backend_v2/app/main.py
from fastapi import FastAPI

from app.core.settings import get_settings


def create_app() -> FastAPI:
    settings = get_settings()
    app = FastAPI(title=settings.app_name)

    @app.get("/health/live")
    def live() -> dict[str, str]:
        return {"status": "ok"}

    @app.get("/health/ready")
    def ready() -> dict[str, str]:
        return {"status": "ready", "dependencies": "stubbed"}

    return app


app = create_app()
```

```python
# backend_v2/tests/conftest.py
import os
import sys
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
if str(ROOT) not in sys.path:
    sys.path.insert(0, str(ROOT))

os.environ.setdefault("APP_ENV", "test")
```

```env
# backend_v2/.env.example
APP_ENV=development
DATABASE_URL=postgresql+psycopg://postgres:postgres@localhost:5432/kcb
REDIS_URL=redis://localhost:6379/0
SENTRY_DSN=
JWT_SECRET=replace-me
CREDENTIAL_ENCRYPTION_KEY=replace-me
```

- [ ] **Step 4: Run test to verify it passes**

Run: `cd backend_v2 && pytest tests/test_health.py -q`
Expected: PASS

### Task 2: Add SQLAlchemy models and readiness checks

**Files:**
- Create: `backend_v2/app/core/db.py`
- Create: `backend_v2/app/models/base.py`
- Create: `backend_v2/app/models/user.py`
- Create: `backend_v2/app/models/academic_binding.py`
- Create: `backend_v2/app/models/encrypted_credential.py`
- Create: `backend_v2/app/models/schedule_snapshot.py`
- Create: `backend_v2/app/models/schedule_sync_state.py`
- Create: `backend_v2/app/models/refresh_token.py`
- Create: `backend_v2/app/models/android_release.py`
- Create: `backend_v2/alembic.ini`
- Create: `backend_v2/alembic/env.py`
- Create: `backend_v2/alembic/versions/20260404_0001_init_tables.py`
- Modify: `backend_v2/app/main.py`
- Create: `backend_v2/tests/test_models.py`

- [ ] **Step 1: Write the failing test**

```python
# backend_v2/tests/test_models.py
from sqlalchemy import create_engine, inspect

from app.models.base import Base
from app.models.user import User
from app.models.academic_binding import AcademicBinding
from app.models.schedule_snapshot import ScheduleSnapshot


def test_tables_can_be_created_in_metadata():
    engine = create_engine("sqlite:///:memory:")

    Base.metadata.create_all(engine)
    tables = set(inspect(engine).get_table_names())

    assert "users" in tables
    assert "academic_bindings" in tables
    assert "schedule_snapshots" in tables


def test_user_to_binding_relationship_is_declared():
    assert User.academic_bindings.property.mapper.class_ is AcademicBinding
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd backend_v2 && pytest tests/test_models.py -q`
Expected: FAIL because model modules do not exist yet.

- [ ] **Step 3: Write minimal implementation**

```python
# backend_v2/app/models/base.py
from sqlalchemy.orm import DeclarativeBase, Mapped, mapped_column


class Base(DeclarativeBase):
    pass


class TimestampMixin:
    created_at: Mapped[str] = mapped_column(default=lambda: "CURRENT_TIMESTAMP")
    updated_at: Mapped[str] = mapped_column(default=lambda: "CURRENT_TIMESTAMP")
```

```python
# backend_v2/app/models/user.py
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.models.base import Base


class User(Base):
    __tablename__ = "users"

    id: Mapped[int] = mapped_column(primary_key=True, autoincrement=True)
    display_name: Mapped[str | None]
    last_login_at: Mapped[str | None]

    academic_bindings = relationship("AcademicBinding", back_populates="user")
```

```python
# backend_v2/app/models/academic_binding.py
from sqlalchemy import ForeignKey, UniqueConstraint
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.models.base import Base


class AcademicBinding(Base):
    __tablename__ = "academic_bindings"
    __table_args__ = (UniqueConstraint("school_code", "academic_username"),)

    id: Mapped[int] = mapped_column(primary_key=True, autoincrement=True)
    user_id: Mapped[int] = mapped_column(ForeignKey("users.id"))
    school_code: Mapped[str] = mapped_column(default="hue")
    academic_username: Mapped[str]
    connector_key: Mapped[str] = mapped_column(default="hue")
    credential_status: Mapped[str] = mapped_column(default="valid")

    user = relationship("User", back_populates="academic_bindings")
    credential = relationship("EncryptedCredential", back_populates="binding", uselist=False)
    sync_state = relationship("ScheduleSyncState", back_populates="binding", uselist=False)
```

```python
# backend_v2/app/models/encrypted_credential.py
from sqlalchemy import ForeignKey
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.models.base import Base


class EncryptedCredential(Base):
    __tablename__ = "encrypted_credentials"

    id: Mapped[int] = mapped_column(primary_key=True, autoincrement=True)
    binding_id: Mapped[int] = mapped_column(ForeignKey("academic_bindings.id"), unique=True)
    encrypted_password: Mapped[str]

    binding = relationship("AcademicBinding", back_populates="credential")
```

```python
# backend_v2/app/models/schedule_snapshot.py
from sqlalchemy import ForeignKey
from sqlalchemy.orm import Mapped, mapped_column

from app.models.base import Base


class ScheduleSnapshot(Base):
    __tablename__ = "schedule_snapshots"

    id: Mapped[int] = mapped_column(primary_key=True, autoincrement=True)
    binding_id: Mapped[int] = mapped_column(ForeignKey("academic_bindings.id"))
    version: Mapped[int] = mapped_column(default=1)
    schedule_hash: Mapped[str]
    semester_label: Mapped[str]
    payload_json: Mapped[str]
    generated_at: Mapped[str]
```

```python
# backend_v2/app/models/schedule_sync_state.py
from sqlalchemy import ForeignKey
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.models.base import Base


class ScheduleSyncState(Base):
    __tablename__ = "schedule_sync_states"

    id: Mapped[int] = mapped_column(primary_key=True, autoincrement=True)
    binding_id: Mapped[int] = mapped_column(ForeignKey("academic_bindings.id"), unique=True)
    current_snapshot_id: Mapped[int | None] = mapped_column(ForeignKey("schedule_snapshots.id"))
    sync_status: Mapped[str] = mapped_column(default="never_synced")
    last_synced_at: Mapped[str | None]
    cache_expires_at: Mapped[str | None]
    last_sync_error: Mapped[str | None]
    schedule_hash: Mapped[str | None]
    schedule_version: Mapped[int] = mapped_column(default=0)

    binding = relationship("AcademicBinding", back_populates="sync_state")
```

```python
# backend_v2/app/models/refresh_token.py
from sqlalchemy import ForeignKey
from sqlalchemy.orm import Mapped, mapped_column

from app.models.base import Base


class RefreshToken(Base):
    __tablename__ = "refresh_tokens"

    id: Mapped[int] = mapped_column(primary_key=True, autoincrement=True)
    user_id: Mapped[int] = mapped_column(ForeignKey("users.id"))
    token_id: Mapped[str] = mapped_column(unique=True)
    device_name: Mapped[str]
    expires_at: Mapped[str]
    revoked_at: Mapped[str | None]
```

```python
# backend_v2/app/models/android_release.py
from sqlalchemy.orm import Mapped, mapped_column

from app.models.base import Base


class AndroidRelease(Base):
    __tablename__ = "android_releases"

    id: Mapped[int] = mapped_column(primary_key=True, autoincrement=True)
    version: Mapped[str]
    build_number: Mapped[int]
    force_update: Mapped[bool] = mapped_column(default=False)
    notes: Mapped[str] = mapped_column(default="")
    apk_url: Mapped[str]
    sha256: Mapped[str]
    published_at: Mapped[str]
```

```python
# backend_v2/app/core/db.py
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker

from app.core.settings import get_settings


settings = get_settings()
engine = create_engine(settings.database_url, future=True)
SessionLocal = sessionmaker(bind=engine, autoflush=False, autocommit=False)
```

```ini
# backend_v2/alembic.ini
[alembic]
script_location = alembic
sqlalchemy.url = postgresql+psycopg://postgres:postgres@localhost:5432/kcb
```

```python
# backend_v2/alembic/env.py
from alembic import context
from sqlalchemy import engine_from_config, pool

from app.models.base import Base
from app.models.user import User
from app.models.academic_binding import AcademicBinding
from app.models.encrypted_credential import EncryptedCredential
from app.models.schedule_snapshot import ScheduleSnapshot
from app.models.schedule_sync_state import ScheduleSyncState
from app.models.refresh_token import RefreshToken
from app.models.android_release import AndroidRelease


config = context.config
target_metadata = Base.metadata


def run_migrations_online() -> None:
    connectable = engine_from_config(
        config.get_section(config.config_ini_section),
        prefix="sqlalchemy.",
        poolclass=pool.NullPool,
    )
    with connectable.connect() as connection:
        context.configure(connection=connection, target_metadata=target_metadata)
        with context.begin_transaction():
            context.run_migrations()
```

```python
# backend_v2/alembic/versions/20260404_0001_init_tables.py
from alembic import op
import sqlalchemy as sa


revision = "20260404_0001"
down_revision = None
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.create_table(
        "users",
        sa.Column("id", sa.Integer(), primary_key=True),
        sa.Column("display_name", sa.String(), nullable=True),
        sa.Column("last_login_at", sa.String(), nullable=True),
    )


def downgrade() -> None:
    op.drop_table("users")
```

```python
# backend_v2/app/main.py
from fastapi import FastAPI

from app.core.settings import get_settings
from app.models.base import Base
from app.core.db import engine


def create_app() -> FastAPI:
    settings = get_settings()
    app = FastAPI(title=settings.app_name)

    @app.get("/health/live")
    def live() -> dict[str, str]:
        return {"status": "ok"}

    @app.get("/health/ready")
    def ready() -> dict[str, str]:
        with engine.connect() as connection:
            connection.exec_driver_sql("SELECT 1")
        return {"status": "ready"}

    return app


app = create_app()
```

- [ ] **Step 4: Run test to verify it passes**

Run: `cd backend_v2 && pytest tests/test_models.py tests/test_health.py -q`
Expected: PASS

### Task 3: Port the HUE connector behind a clean interface

**Files:**
- Create: `backend_v2/app/modules/connectors/__init__.py`
- Create: `backend_v2/app/modules/connectors/base.py`
- Create: `backend_v2/app/modules/connectors/errors.py`
- Create: `backend_v2/app/modules/connectors/hue_connector.py`
- Create: `backend_v2/app/modules/connectors/hue_parser.py`
- Create: `backend_v2/tests/fixtures/hue_schedule.html`
- Create: `backend_v2/tests/test_hue_connector.py`

- [ ] **Step 1: Write the failing test**

```python
# backend_v2/tests/test_hue_connector.py
from unittest.mock import patch

from app.modules.connectors.hue_connector import HUEConnector


@patch("app.modules.connectors.hue_connector.ddddocr.DdddOcr")
@patch("app.modules.connectors.hue_connector.requests.Session")
def test_connector_uses_supplied_credentials(session_cls, ocr_cls):
    session = session_cls.return_value
    ocr_cls.return_value.classification.return_value = "1234"

    response_home = type("R", (), {"text": "", "status_code": 200, "url": "https://jwxt.hue.edu.cn"})()
    response_sess = type("R", (), {"text": "abc#111", "status_code": 200, "url": "https://jwxt.hue.edu.cn"})()
    response_captcha = type("R", (), {"content": b"img", "status_code": 200, "url": "https://jwxt.hue.edu.cn"})()
    response_login = type("R", (), {"text": "", "status_code": 200, "url": "https://jwxt.hue.edu.cn/xsMain.jsp"})()
    response_table = type(
        "R",
        (),
        {"text": "<div id='timetableDiv'>2026春</div><table id='kbtable'></table>", "status_code": 200, "url": "https://jwxt.hue.edu.cn"},
    )()
    session.get.side_effect = [response_home, response_sess, response_captcha, response_table]
    session.post.return_value = response_login

    connector = HUEConnector()
    connector.fetch_schedule("demo_student_id", "pw123")

    post_data = session.post.call_args.kwargs["data"]
    assert "demo_student_id" not in post_data["encoded"]


def test_parser_reads_fixture_into_normalized_courses():
    html = """
    <div id="timetableDiv">2026春</div>
    <table id="kbtable"><tr><th></th></tr></table>
    """

    result = HUEConnector().parse_schedule_html(html)

    assert result.semester_label == "2026春"
    assert isinstance(result.courses, list)
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd backend_v2 && pytest tests/test_hue_connector.py -q`
Expected: FAIL because connector modules do not exist yet.

- [ ] **Step 3: Write minimal implementation**

```python
# backend_v2/app/modules/connectors/base.py
from dataclasses import dataclass


@dataclass
class NormalizedCourse:
    name: str
    teacher: str
    room: str
    weekday: int
    lesson_start: int
    lesson_end: int
    raw_weeks: str
    parsed_weeks: list[int]


@dataclass
class NormalizedSchedule:
    semester_label: str
    generated_at: str
    courses: list[NormalizedCourse]


class AcademicConnector:
    connector_key = "base"

    def validate_credentials(self, username: str, password: str) -> None:
        self.fetch_schedule(username, password)

    def fetch_schedule(self, username: str, password: str) -> NormalizedSchedule:
        raise NotImplementedError
```

```python
# backend_v2/app/modules/connectors/errors.py
class ConnectorError(Exception):
    pass


class InvalidCredentialsError(ConnectorError):
    pass
```

```python
# backend_v2/app/modules/connectors/hue_parser.py
from bs4 import BeautifulSoup

from app.modules.connectors.base import NormalizedCourse, NormalizedSchedule


def parse_schedule_html(html: str) -> NormalizedSchedule:
    soup = BeautifulSoup(html, "html.parser")
    semester = soup.find("div", {"id": "timetableDiv"})
    semester_label = semester.get_text(strip=True) if semester else ""

    return NormalizedSchedule(
        semester_label=semester_label,
        generated_at="generated-at-runtime",
        courses=[],
    )
```

```html
<!-- backend_v2/tests/fixtures/hue_schedule.html -->
<div id="timetableDiv">2026春</div>
<table id="kbtable">
  <tr><th>time</th></tr>
</table>
```

```python
# backend_v2/app/modules/connectors/hue_connector.py
from datetime import datetime, timezone

import requests

try:
    import ddddocr
except ImportError:
    ddddocr = None

from app.modules.connectors.base import AcademicConnector, NormalizedSchedule
from app.modules.connectors.hue_parser import parse_schedule_html


class HUEConnector(AcademicConnector):
    connector_key = "hue"
    base_url = "https://jwxt.hue.edu.cn"

    def parse_schedule_html(self, html: str) -> NormalizedSchedule:
        result = parse_schedule_html(html)
        result.generated_at = datetime.now(timezone.utc).isoformat()
        return result

    def fetch_schedule(self, username: str, password: str) -> NormalizedSchedule:
        if ddddocr is None:
            raise RuntimeError("ddddocr is required")

        session = requests.Session()
        session.get(self.base_url, timeout=10)
        sess_response = session.get(f"{self.base_url}/Logon.do?method=logon&flag=sess", timeout=10)
        scode, sxh = sess_response.text.split("#")

        captcha_response = session.get(f"{self.base_url}/verifycode.servlet", timeout=10)
        captcha = ddddocr.DdddOcr().classification(captcha_response.content)

        code = username + "%%%" + password
        encoded = ""
        sxh_list = [int(item) for item in sxh]
        for index, char in enumerate(code):
            if index < len(sxh_list):
                encoded += char + scode[: sxh_list[index]]
                scode = scode[sxh_list[index] :]
            else:
                encoded += code[index:]
                break

        login_response = session.post(
            f"{self.base_url}/Logon.do?method=logon",
            data={"useDogCode": "", "encoded": encoded, "RANDOMCODE": captcha},
            allow_redirects=True,
            timeout=10,
        )
        if "xsMain.jsp" not in login_response.url:
            raise RuntimeError("invalid academic credentials")

        table_response = session.get(f"{self.base_url}/jsxsd/xskb/xskb_list.do", timeout=10)
        return self.parse_schedule_html(table_response.text)
```

- [ ] **Step 4: Run test to verify it passes**

Run: `cd backend_v2 && pytest tests/test_hue_connector.py -q`
Expected: PASS

### Task 4: Implement login, refresh, and encrypted credential storage

**Files:**
- Create: `backend_v2/app/core/security.py`
- Create: `backend_v2/app/modules/auth/schemas.py`
- Create: `backend_v2/app/modules/auth/service.py`
- Create: `backend_v2/app/modules/auth/router.py`
- Create: `backend_v2/app/modules/credentials/service.py`
- Modify: `backend_v2/app/main.py`
- Create: `backend_v2/tests/test_auth_api.py`

- [ ] **Step 1: Write the failing test**

```python
# backend_v2/tests/test_auth_api.py
from fastapi.testclient import TestClient

from app.main import create_app


def test_login_validates_academic_credentials_and_returns_tokens(monkeypatch):
    from app.modules.auth import service as auth_service

    def fake_login(payload):
        return {
            "access_token": "access-token",
            "refresh_token": "refresh-token",
            "token_type": "bearer",
            "user": {"id": 1, "school_code": "hue", "academic_username": "demo_student_id"},
        }

    monkeypatch.setattr(auth_service, "login_with_academic_credentials", fake_login)
    client = TestClient(create_app())

    response = client.post(
        "/api/v1/auth/login",
        json={"school_code": "hue", "academic_username": "demo_student_id", "password": "pw123", "device_name": "Pixel"},
    )

    assert response.status_code == 200
    assert response.json()["token_type"] == "bearer"


def test_refresh_rotates_refresh_token(monkeypatch):
    from app.modules.auth import service as auth_service

    monkeypatch.setattr(
        auth_service,
        "refresh_session",
        lambda token: {"access_token": "new-access", "refresh_token": "new-refresh", "token_type": "bearer"},
    )
    client = TestClient(create_app())

    response = client.post("/api/v1/auth/refresh", json={"refresh_token": "old-refresh"})

    assert response.status_code == 200
    assert response.json()["refresh_token"] == "new-refresh"
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd backend_v2 && pytest tests/test_auth_api.py -q`
Expected: FAIL because auth router and service do not exist yet.

- [ ] **Step 3: Write minimal implementation**

```python
# backend_v2/app/core/security.py
import os
import secrets
from datetime import datetime, timedelta, timezone

import jwt
from cryptography.fernet import Fernet


JWT_SECRET = os.environ.get("JWT_SECRET", "dev-secret")
CREDENTIAL_ENCRYPTION_KEY = os.environ["CREDENTIAL_ENCRYPTION_KEY"]


def create_access_token(user_id: int) -> str:
    payload = {"sub": str(user_id), "exp": datetime.now(timezone.utc) + timedelta(hours=2)}
    return jwt.encode(payload, JWT_SECRET, algorithm="HS256")


def issue_refresh_token() -> str:
    return secrets.token_urlsafe(32)


def encrypt_password(password: str) -> str:
    return Fernet(CREDENTIAL_ENCRYPTION_KEY.encode("utf-8")).encrypt(password.encode("utf-8")).decode("utf-8")
```

```python
# backend_v2/app/modules/auth/schemas.py
from pydantic import BaseModel


class LoginRequest(BaseModel):
    school_code: str
    academic_username: str
    password: str
    device_name: str


class RefreshRequest(BaseModel):
    refresh_token: str
```

```python
# backend_v2/app/modules/auth/service.py
from app.core.security import create_access_token, issue_refresh_token
from app.modules.credentials.service import encrypt_academic_password


def login_with_academic_credentials(payload) -> dict:
    encrypted_password = encrypt_academic_password(payload.password)
    return {
        "access_token": create_access_token(1),
        "refresh_token": issue_refresh_token(),
        "token_type": "bearer",
        "user": {
            "id": 1,
            "school_code": payload.school_code,
            "academic_username": payload.academic_username,
        },
    }


def refresh_session(refresh_token: str) -> dict:
    return {
        "access_token": create_access_token(1),
        "refresh_token": issue_refresh_token(),
        "token_type": "bearer",
    }
```

```python
# backend_v2/app/modules/credentials/service.py
from app.core.security import encrypt_password


def encrypt_academic_password(password: str) -> str:
    return encrypt_password(password)
```

```python
# backend_v2/app/modules/auth/router.py
from fastapi import APIRouter

from app.modules.auth.schemas import LoginRequest, RefreshRequest
from app.modules.auth.service import login_with_academic_credentials, refresh_session


router = APIRouter(prefix="/api/v1/auth", tags=["auth"])


@router.post("/login")
def login(payload: LoginRequest) -> dict:
    return login_with_academic_credentials(payload)


@router.post("/refresh")
def refresh(payload: RefreshRequest) -> dict:
    return refresh_session(payload.refresh_token)
```

```python
# backend_v2/app/main.py
from fastapi import FastAPI

from app.core.settings import get_settings
from app.modules.auth.router import router as auth_router


def create_app() -> FastAPI:
    settings = get_settings()
    app = FastAPI(title=settings.app_name)
    app.include_router(auth_router)

    @app.get("/health/live")
    def live() -> dict[str, str]:
        return {"status": "ok"}

    @app.get("/health/ready")
    def ready() -> dict[str, str]:
        return {"status": "ready"}

    return app
```

- [ ] **Step 4: Run test to verify it passes**

Run: `cd backend_v2 && pytest tests/test_auth_api.py -q`
Expected: PASS

### Task 5: Add binding, normalization, and schedule persistence services

**Files:**
- Create: `backend_v2/app/modules/schedule/schemas.py`
- Create: `backend_v2/app/modules/schedule/hash.py`
- Create: `backend_v2/app/modules/schedule/service.py`
- Create: `backend_v2/app/modules/schedule/repository.py`
- Create: `backend_v2/app/modules/credentials/router.py`
- Create: `backend_v2/tests/test_schedule_service.py`

- [ ] **Step 1: Write the failing test**

```python
# backend_v2/tests/test_schedule_service.py
from app.modules.schedule.hash import compute_schedule_hash


def test_schedule_hash_is_stable_for_equal_payloads():
    payload = {
        "semester_label": "2026春",
        "courses": [
            {
                "name": "软件测试技术",
                "teacher": "张三",
                "room": "S4409",
                "weekday": 1,
                "lesson_start": 1,
                "lesson_end": 2,
                "raw_weeks": "1-16(周)",
                "parsed_weeks": [1, 2, 3],
            }
        ],
    }

    assert compute_schedule_hash(payload) == compute_schedule_hash(payload)
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd backend_v2 && pytest tests/test_schedule_service.py -q`
Expected: FAIL because schedule modules do not exist yet.

- [ ] **Step 3: Write minimal implementation**

```python
# backend_v2/app/modules/schedule/hash.py
import hashlib
import json


def compute_schedule_hash(payload: dict) -> str:
    encoded = json.dumps(payload, ensure_ascii=False, sort_keys=True).encode("utf-8")
    return hashlib.sha256(encoded).hexdigest()
```

```python
# backend_v2/app/modules/schedule/schemas.py
from pydantic import BaseModel


class CourseOut(BaseModel):
    name: str
    teacher: str
    room: str
    weekday: int
    lesson_start: int
    lesson_end: int
    raw_weeks: str
    parsed_weeks: list[int]


class ScheduleOut(BaseModel):
    semester_label: str
    generated_at: str
    is_stale: bool
    last_synced_at: str | None
    courses: list[CourseOut]
```

```python
# backend_v2/app/modules/schedule/service.py
from app.modules.schedule.hash import compute_schedule_hash


def normalize_connector_schedule(connector_result) -> dict:
    payload = {
        "semester_label": connector_result.semester_label,
        "generated_at": connector_result.generated_at,
        "courses": [
            {
                "name": course.name,
                "teacher": course.teacher,
                "room": course.room,
                "weekday": course.weekday,
                "lesson_start": course.lesson_start,
                "lesson_end": course.lesson_end,
                "raw_weeks": course.raw_weeks,
                "parsed_weeks": course.parsed_weeks,
            }
            for course in connector_result.courses
        ],
    }
    payload["schedule_hash"] = compute_schedule_hash(payload)
    return payload
```

```python
# backend_v2/app/modules/schedule/repository.py
def serialize_snapshot(payload: dict) -> dict:
    return {
        "semester_label": payload["semester_label"],
        "generated_at": payload["generated_at"],
        "schedule_hash": payload["schedule_hash"],
        "courses": payload["courses"],
    }
```

```python
# backend_v2/app/modules/credentials/router.py
from fastapi import APIRouter
from pydantic import BaseModel


router = APIRouter(prefix="/api/v1/jw", tags=["academic-binding"])


class BindRequest(BaseModel):
    school_code: str
    academic_username: str
    password: str


@router.post("/bind")
def bind(payload: BindRequest) -> dict:
    return {"status": "bound", "school_code": payload.school_code, "academic_username": payload.academic_username}


@router.post("/rebind")
def rebind(payload: BindRequest) -> dict:
    return {"status": "rebound", "school_code": payload.school_code, "academic_username": payload.academic_username}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `cd backend_v2 && pytest tests/test_schedule_service.py -q`
Expected: PASS

### Task 6: Serve cached schedule reads and sync status APIs

**Files:**
- Create: `backend_v2/app/modules/schedule/cache.py`
- Create: `backend_v2/app/modules/schedule/router.py`
- Modify: `backend_v2/app/main.py`
- Create: `backend_v2/tests/test_schedule_api.py`

- [ ] **Step 1: Write the failing test**

```python
# backend_v2/tests/test_schedule_api.py
from fastapi.testclient import TestClient

from app.main import create_app


def test_current_schedule_returns_stale_payload_when_cache_exists(monkeypatch):
    from app.modules.schedule import router as schedule_router

    monkeypatch.setattr(
        schedule_router,
        "read_current_schedule",
        lambda user_id: {
            "semester_label": "2026春",
            "generated_at": "2026-04-04T10:00:00Z",
            "is_stale": True,
            "last_synced_at": "2026-04-04T08:00:00Z",
            "courses": [],
        },
    )

    client = TestClient(create_app())
    response = client.get("/api/v1/schedule/current")

    assert response.status_code == 200
    assert response.json()["is_stale"] is True


def test_status_endpoint_returns_sync_metadata(monkeypatch):
    from app.modules.schedule import router as schedule_router

    monkeypatch.setattr(
        schedule_router,
        "read_sync_status",
        lambda user_id: {"sync_status": "synced", "schedule_version": 3, "last_sync_error": None},
    )

    client = TestClient(create_app())
    response = client.get("/api/v1/schedule/status")

    assert response.status_code == 200
    assert response.json()["schedule_version"] == 3
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd backend_v2 && pytest tests/test_schedule_api.py -q`
Expected: FAIL because schedule router does not exist yet.

- [ ] **Step 3: Write minimal implementation**

```python
# backend_v2/app/modules/schedule/cache.py
import json

from redis import Redis

from app.core.settings import get_settings


redis_client = Redis.from_url(get_settings().redis_url, decode_responses=True)


def schedule_key(user_id: int) -> str:
    return f"schedule:{user_id}:current"


def get_cached_schedule(user_id: int) -> dict | None:
    raw = redis_client.get(schedule_key(user_id))
    return json.loads(raw) if raw else None
```

```python
# backend_v2/app/modules/schedule/router.py
from fastapi import APIRouter


router = APIRouter(prefix="/api/v1/schedule", tags=["schedule"])


def read_current_schedule(user_id: int) -> dict:
    return {
        "semester_label": "2026春",
        "generated_at": "2026-04-04T10:00:00Z",
        "is_stale": False,
        "last_synced_at": "2026-04-04T10:00:00Z",
        "courses": [],
    }


def read_sync_status(user_id: int) -> dict:
    return {
        "sync_status": "synced",
        "schedule_version": 1,
        "last_sync_error": None,
    }


@router.get("/current")
def current_schedule() -> dict:
    return read_current_schedule(user_id=1)


@router.get("/status")
def sync_status() -> dict:
    return read_sync_status(user_id=1)
```

```python
# backend_v2/app/main.py
from fastapi import FastAPI

from app.core.settings import get_settings
from app.modules.auth.router import router as auth_router
from app.modules.credentials.router import router as credentials_router
from app.modules.schedule.router import router as schedule_router


def create_app() -> FastAPI:
    settings = get_settings()
    app = FastAPI(title=settings.app_name)
    app.include_router(auth_router)
    app.include_router(credentials_router)
    app.include_router(schedule_router)

    @app.get("/health/live")
    def live() -> dict[str, str]:
        return {"status": "ok"}

    @app.get("/health/ready")
    def ready() -> dict[str, str]:
        return {"status": "ready"}

    return app
```

- [ ] **Step 4: Run test to verify it passes**

Run: `cd backend_v2 && pytest tests/test_schedule_api.py -q`
Expected: PASS

### Task 7: Add Celery refresh jobs and manual refresh endpoint

**Files:**
- Create: `backend_v2/app/modules/tasks/celery_app.py`
- Create: `backend_v2/app/modules/tasks/schedule_tasks.py`
- Modify: `backend_v2/app/modules/schedule/router.py`
- Create: `backend_v2/tests/test_schedule_tasks.py`

- [ ] **Step 1: Write the failing test**

```python
# backend_v2/tests/test_schedule_tasks.py
from app.modules.tasks.schedule_tasks import retry_delay_seconds


def test_retry_backoff_grows_predictably():
    assert retry_delay_seconds(0) == 300
    assert retry_delay_seconds(1) == 900
    assert retry_delay_seconds(2) == 1800
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd backend_v2 && pytest tests/test_schedule_tasks.py -q`
Expected: FAIL because Celery task modules do not exist yet.

- [ ] **Step 3: Write minimal implementation**

```python
# backend_v2/app/modules/tasks/celery_app.py
from celery import Celery

from app.core.settings import get_settings


celery_app = Celery("kcb-backend-v2", broker=get_settings().redis_url, backend=get_settings().redis_url)
celery_app.conf.task_default_queue = "schedule"
```

```python
# backend_v2/app/modules/tasks/schedule_tasks.py
from app.modules.tasks.celery_app import celery_app


def retry_delay_seconds(retry_index: int) -> int:
    return [300, 900, 1800][min(retry_index, 2)]


@celery_app.task(bind=True, autoretry_for=(Exception,), retry_backoff=False, max_retries=3)
def sync_schedule(self, binding_id: int) -> None:
    return None
```

```python
# backend_v2/app/modules/schedule/router.py
from fastapi import APIRouter, status

from app.modules.tasks.schedule_tasks import sync_schedule


router = APIRouter(prefix="/api/v1/schedule", tags=["schedule"])


@router.post("/refresh", status_code=status.HTTP_202_ACCEPTED)
def refresh_schedule() -> dict:
    sync_schedule.delay(binding_id=1)
    return {"code": "SYNC_IN_PROGRESS", "status": "queued"}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `cd backend_v2 && pytest tests/test_schedule_tasks.py -q`
Expected: PASS

### Task 8: Add middleware, uniform errors, Sentry, and Android update APIs

**Files:**
- Create: `backend_v2/app/middleware/request_id.py`
- Create: `backend_v2/app/middleware/error_handler.py`
- Create: `backend_v2/app/modules/updates/router.py`
- Modify: `backend_v2/app/main.py`
- Create: `backend_v2/docker-compose.yml`
- Create: `backend_v2/README.md`
- Create: `backend_v2/tests/test_updates_api.py`

- [ ] **Step 1: Write the failing test**

```python
# backend_v2/tests/test_updates_api.py
from fastapi.testclient import TestClient

from app.main import create_app


def test_android_update_endpoint_returns_release_payload(monkeypatch):
    from app.modules.updates import router as updates_router

    monkeypatch.setattr(
        updates_router,
        "read_latest_android_release",
        lambda: {
            "platform": "android",
            "version": "1.0.1",
            "build_number": 2,
            "force_update": False,
            "notes": "Schedule polish",
            "apk_url": "https://example.com/app.apk",
            "sha256": "abc",
            "published_at": "2026-04-04T10:00:00Z",
        },
    )

    client = TestClient(create_app())
    response = client.get("/api/v1/app/update/android")

    assert response.status_code == 200
    assert response.json()["build_number"] == 2
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd backend_v2 && pytest tests/test_updates_api.py -q`
Expected: FAIL because the updates router does not exist yet.

- [ ] **Step 3: Write minimal implementation**

```python
# backend_v2/app/middleware/request_id.py
import uuid

from starlette.middleware.base import BaseHTTPMiddleware


class RequestIdMiddleware(BaseHTTPMiddleware):
    async def dispatch(self, request, call_next):
        request.state.request_id = uuid.uuid4().hex
        response = await call_next(request)
        response.headers["X-Request-Id"] = request.state.request_id
        return response
```

```python
# backend_v2/app/middleware/error_handler.py
from fastapi import Request
from fastapi.responses import JSONResponse


async def unhandled_exception_handler(request: Request, exc: Exception) -> JSONResponse:
    return JSONResponse(
        status_code=500,
        content={
            "code": "INTERNAL_ERROR",
            "message": "Unexpected server error.",
            "request_id": getattr(request.state, "request_id", None),
            "details": {},
        },
    )
```

```python
# backend_v2/app/modules/updates/router.py
from fastapi import APIRouter


router = APIRouter(prefix="/api/v1/app/update", tags=["updates"])


def read_latest_android_release() -> dict:
    return {
        "platform": "android",
        "version": "1.0.0",
        "build_number": 1,
        "force_update": False,
        "notes": "",
        "apk_url": "",
        "sha256": "",
        "published_at": "1970-01-01T00:00:00Z",
    }


@router.get("/android")
def latest_android_release() -> dict:
    return read_latest_android_release()
```

```python
# backend_v2/app/main.py
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from fastapi.middleware.gzip import GZipMiddleware

from app.core.settings import get_settings
from app.middleware.error_handler import unhandled_exception_handler
from app.middleware.request_id import RequestIdMiddleware
from app.modules.auth.router import router as auth_router
from app.modules.credentials.router import router as credentials_router
from app.modules.schedule.router import router as schedule_router
from app.modules.updates.router import router as updates_router


def create_app() -> FastAPI:
    settings = get_settings()
    app = FastAPI(title=settings.app_name)
    app.add_middleware(RequestIdMiddleware)
    app.add_middleware(GZipMiddleware, minimum_size=500)
    app.add_middleware(
        CORSMiddleware,
        allow_origins=["*"],
        allow_methods=["*"],
        allow_headers=["*"],
    )
    app.add_exception_handler(Exception, unhandled_exception_handler)

    app.include_router(auth_router)
    app.include_router(credentials_router)
    app.include_router(schedule_router)
    app.include_router(updates_router)

    @app.get("/health/live")
    def live() -> dict[str, str]:
        return {"status": "ok"}

    @app.get("/health/ready")
    def ready() -> dict[str, str]:
        return {"status": "ready"}

    return app
```

```yaml
# backend_v2/docker-compose.yml
services:
  api:
    build: .
    command: uvicorn app.main:app --host 0.0.0.0 --port 8000
    env_file: .env
    ports:
      - "8000:8000"
    depends_on:
      - postgres
      - redis
  worker:
    build: .
    command: celery -A app.modules.tasks.celery_app.celery_app worker --loglevel=INFO
    env_file: .env
    depends_on:
      - postgres
      - redis
  beat:
    build: .
    command: celery -A app.modules.tasks.celery_app.celery_app beat --loglevel=INFO
    env_file: .env
    depends_on:
      - postgres
      - redis
  postgres:
    image: postgres:17
    environment:
      POSTGRES_DB: kcb
      POSTGRES_USER: postgres
      POSTGRES_PASSWORD: postgres
    ports:
      - "5432:5432"
  redis:
    image: redis:8
    ports:
      - "6379:6379"
```

````md
# backend_v2/README.md
# backend_v2

## Start

```bash
docker compose up --build
```

## Verify

```bash
curl http://127.0.0.1:8000/health/live
curl http://127.0.0.1:8000/api/v1/app/update/android
```
````

- [ ] **Step 4: Run test to verify it passes**

Run: `cd backend_v2 && pytest tests/test_updates_api.py tests/test_auth_api.py tests/test_schedule_api.py -q`
Expected: PASS

- [ ] **Step 5: Run the full backend verification suite**

Run: `cd backend_v2 && pytest tests -q`
Expected: PASS

- [ ] **Step 6: Run local stack verification**

Run: `cd backend_v2 && docker compose up --build`
Expected:
- FastAPI starts on `http://127.0.0.1:8000`
- `GET /health/live` returns `{"status":"ok"}`
- `GET /api/v1/app/update/android` returns JSON
- Celery worker connects to Redis without crashing

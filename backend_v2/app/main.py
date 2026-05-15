from pathlib import Path

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from fastapi.middleware.gzip import GZipMiddleware
from fastapi.staticfiles import StaticFiles

import app.models  # noqa: F401
from app.core.db import engine
from app.core.settings import get_settings
from app.models.base import Base
from app.middleware.error_handler import (
    invalid_credentials_exception_handler,
    unhandled_exception_handler,
)
from app.middleware.request_id import RequestIdMiddleware
from app.modules.connectors.errors import InvalidCredentialsError
from app.modules.auth.router import router as auth_router
from app.modules.admin.monitoring import router as admin_monitoring_router
from app.modules.credentials.router import router as credentials_router
from app.modules.schedule.cache import redis_client
from app.modules.schedule.router import router as schedule_router
from app.modules.updates.router import router as updates_router


def create_app() -> FastAPI:
    settings = get_settings()
    Base.metadata.create_all(engine)
    app = FastAPI(title=settings.app_name)
    app.add_middleware(RequestIdMiddleware)
    app.add_middleware(GZipMiddleware, minimum_size=500)
    app.add_middleware(
        CORSMiddleware,
        allow_origins=["*"],
        allow_methods=["*"],
        allow_headers=["*"],
    )
    app.add_exception_handler(
        InvalidCredentialsError,
        invalid_credentials_exception_handler,
    )
    app.add_exception_handler(Exception, unhandled_exception_handler)
    app.include_router(auth_router)
    app.include_router(admin_monitoring_router)
    app.include_router(credentials_router)
    app.include_router(schedule_router)
    app.include_router(updates_router)

    @app.get("/health/live")
    def live() -> dict[str, str]:
        return {"status": "ok"}

    @app.get("/health/ready")
    def ready() -> dict[str, str]:
        database_status = "ok"
        with engine.connect() as connection:
            connection.exec_driver_sql("SELECT 1")

        redis_status = "ok"
        if redis_client is not None:
            try:
                redis_client.ping()
            except Exception:
                redis_status = "degraded"
        else:
            redis_status = "fallback"

        return {
            "status": "ready",
            "database": database_status,
            "redis": redis_status,
        }

    site_dir = Path(__file__).resolve().parents[1] / "site"
    if site_dir.is_dir():
        app.mount("/", StaticFiles(directory=site_dir, html=True), name="site")

    return app


app = create_app()

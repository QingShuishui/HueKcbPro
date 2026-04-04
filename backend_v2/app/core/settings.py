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

from pathlib import Path

from fastapi.testclient import TestClient

from app.main import create_app


def test_ready_healthcheck_reports_database_and_redis_status():
    client = TestClient(create_app())

    response = client.get("/health/ready")

    assert response.status_code == 200
    payload = response.json()
    assert payload["status"] == "ready"
    assert "database" in payload
    assert "redis" in payload


def test_alembic_migration_mentions_all_core_tables():
    migration = Path("alembic/versions/20260404_0001_init_tables.py").read_text(
        encoding="utf-8",
    )

    for table_name in [
        "users",
        "academic_bindings",
        "encrypted_credentials",
        "schedule_snapshots",
        "schedule_sync_states",
        "refresh_tokens",
        "android_releases",
    ]:
        assert f'"{table_name}"' in migration


def test_pyproject_contains_build_system_for_docker_install():
    pyproject = Path("pyproject.toml").read_text(encoding="utf-8")

    assert "[build-system]" in pyproject

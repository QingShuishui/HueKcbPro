from pathlib import Path


def test_alembic_env_reads_database_url_from_settings():
    env_py = Path("alembic/env.py").read_text(encoding="utf-8")

    assert "get_settings" in env_py
    assert 'config.set_main_option("sqlalchemy.url", settings.database_url)' in env_py


def test_docker_compose_includes_migration_and_healthchecks():
    compose = Path("docker-compose.yml").read_text(encoding="utf-8")

    assert "migrate:" in compose
    assert "healthcheck:" in compose
    assert "condition: service_healthy" in compose
    assert "alembic upgrade head" in compose


def test_readme_documents_real_stack_startup():
    readme = Path("README.md").read_text(encoding="utf-8")

    assert "postgres" in readme.lower()
    assert "redis" in readme.lower()
    assert "celery" in readme.lower()
    assert "alembic upgrade head" in readme

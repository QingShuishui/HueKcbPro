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

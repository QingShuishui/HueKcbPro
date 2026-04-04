from fastapi.testclient import TestClient

from app.main import create_app
from app.modules.connectors.errors import InvalidCredentialsError


def test_login_validates_academic_credentials_and_returns_tokens(monkeypatch):
    from app.modules.auth import service as auth_service

    def fake_login(payload):
        return {
            "access_token": "access-token",
            "refresh_token": "refresh-token",
            "token_type": "bearer",
            "user": {
                "id": 1,
                "school_code": "hue",
                "academic_username": "demo_student_id",
            },
        }

    monkeypatch.setattr(auth_service, "login_with_academic_credentials", fake_login)
    client = TestClient(create_app())

    response = client.post(
        "/api/v1/auth/login",
        json={
            "school_code": "hue",
            "academic_username": "demo_student_id",
            "password": "pw123",
            "device_name": "Pixel",
        },
    )

    assert response.status_code == 200
    assert response.json()["token_type"] == "bearer"


def test_refresh_rotates_refresh_token(monkeypatch):
    from app.modules.auth import service as auth_service

    monkeypatch.setattr(
        auth_service,
        "refresh_session",
        lambda token: {
            "access_token": "new-access",
            "refresh_token": "new-refresh",
            "token_type": "bearer",
        },
    )
    client = TestClient(create_app())

    response = client.post(
        "/api/v1/auth/refresh",
        json={"refresh_token": "old-refresh"},
    )

    assert response.status_code == 200
    assert response.json()["refresh_token"] == "new-refresh"


def test_login_returns_400_for_invalid_academic_credentials(monkeypatch):
    from app.modules.auth import service as auth_service

    def fake_login(_payload):
      raise InvalidCredentialsError("invalid academic credentials")

    monkeypatch.setattr(auth_service, "login_with_academic_credentials", fake_login)
    client = TestClient(create_app())

    response = client.post(
        "/api/v1/auth/login",
        json={
            "school_code": "hue",
            "academic_username": "demo_student_id",
            "password": "wrong",
            "device_name": "Pixel",
        },
    )

    assert response.status_code == 400
    assert response.json()["code"] == "INVALID_CREDENTIALS"


def test_refresh_returns_401_for_unknown_refresh_token(monkeypatch):
    from app.modules.auth import service as auth_service

    monkeypatch.setattr(auth_service, "refresh_session", lambda token: (_ for _ in ()).throw(
        ValueError("invalid refresh token")
    ))
    client = TestClient(create_app())

    response = client.post(
        "/api/v1/auth/refresh",
        json={"refresh_token": "missing-token"},
    )

    assert response.status_code == 401
    assert response.json()["code"] == "INVALID_REFRESH_TOKEN"

from datetime import datetime, timezone

from fastapi.testclient import TestClient

from app.core.settings import get_settings
from app.main import create_app
from app.modules.connectors.base import NormalizedCourse, NormalizedSchedule


def _fake_schedule(self, username: str, password: str):
    return NormalizedSchedule(
        semester_label="2026春",
        generated_at=datetime.now(timezone.utc).isoformat(),
        courses=[
            NormalizedCourse(
                name="软件测试技术",
                code="SIT",
                teacher="张三",
                room="S4409",
                weekday=1,
                lesson_start=1,
                lesson_end=2,
                raw_weeks="1-16(周)",
                parsed_weeks=[1, 2, 3],
            )
        ],
    )


def test_monitoring_requires_admin_token(monkeypatch):
    monkeypatch.setenv("ADMIN_TOKEN", "secret")
    get_settings.cache_clear()

    client = TestClient(create_app())
    response = client.get("/api/v1/admin/monitor/summary")

    assert response.status_code == 401


def test_monitoring_reports_users_versions_and_schedule_pressure(monkeypatch):
    from app.modules.auth import service as auth_service

    monkeypatch.setenv("ADMIN_TOKEN", "secret")
    get_settings.cache_clear()
    monkeypatch.setattr(auth_service.HUEConnector, "fetch_schedule", _fake_schedule)

    client = TestClient(create_app())
    login_response = client.post(
        "/api/v1/auth/login",
        json={
            "school_code": "hue",
            "academic_username": "demo_student_id",
            "password": "pw123",
            "device_name": "Pixel 9",
            "platform": "android",
            "app_version": "2.0.6",
            "app_build": "206",
        },
    )
    access_token = login_response.json()["access_token"]
    client.get(
        "/api/v1/schedule/current",
        headers={"Authorization": f"Bearer {access_token}"},
    )
    client.post(
        "/api/v1/schedule/refresh",
        headers={"Authorization": f"Bearer {access_token}"},
    )

    admin_headers = {"X-Admin-Token": "secret"}
    summary = client.get(
        "/api/v1/admin/monitor/summary",
        headers=admin_headers,
    )
    users = client.get("/api/v1/admin/monitor/users", headers=admin_headers)
    logs = client.get("/api/v1/admin/monitor/schedule-logs", headers=admin_headers)

    assert summary.status_code == 200
    assert summary.json()["users"]["total"] == 1
    assert summary.json()["schedule"]["current_count"] == 1
    assert summary.json()["schedule"]["refresh_count"] == 1
    assert summary.json()["schedule"]["average_duration_ms"] >= 0

    assert users.status_code == 200
    assert users.json()["users"][0]["academic_username"] == "demo_student_id"
    assert users.json()["users"][0]["app_version"] == "2.0.6"
    assert users.json()["users"][0]["app_build"] == "206"
    assert users.json()["users"][0]["platform"] == "android"

    assert logs.status_code == 200
    actions = {entry["action"] for entry in logs.json()["logs"]}
    assert actions == {"current", "refresh"}
    assert logs.json()["logs"][0]["academic_username"] == "demo_student_id"

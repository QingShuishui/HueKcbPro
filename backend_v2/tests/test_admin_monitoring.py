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


def test_admin_can_force_refresh_the_global_semester_calendar(monkeypatch):
    from app.modules.connectors.hue_connector import HUEConnector

    monkeypatch.setenv("ADMIN_TOKEN", "secret")
    monkeypatch.setenv("ACADEMIC_CALENDAR_PROBE_USERNAME", "calendar-probe")
    monkeypatch.setenv("ACADEMIC_CALENDAR_PROBE_PASSWORD", "calendar-password")
    get_settings.cache_clear()
    monkeypatch.setattr(
        HUEConnector,
        "fetch_academic_calendar",
        lambda _self, _username, _password: ("2026-08-31", "2027-01-31", 22),
        raising=False,
    )

    client = TestClient(create_app())
    response = client.post(
        "/api/v1/admin/monitor/calendar/refresh",
        headers={"X-Admin-Token": "secret"},
    )

    assert response.status_code == 200
    assert response.json() == {
        "semester_start_date": "2026-08-31",
        "semester_end_date": "2027-01-31",
        "total_weeks": 22,
        "term_id": "2026-2027-1",
    }


def test_calendar_refresh_keeps_at_least_eighteen_weeks(monkeypatch):
    from app.modules.connectors.hue_connector import HUEConnector

    monkeypatch.setenv("ADMIN_TOKEN", "secret")
    monkeypatch.setenv("ACADEMIC_CALENDAR_PROBE_USERNAME", "calendar-probe")
    monkeypatch.setenv("ACADEMIC_CALENDAR_PROBE_PASSWORD", "calendar-password")
    get_settings.cache_clear()
    monkeypatch.setattr(
        HUEConnector,
        "fetch_academic_calendar",
        lambda _self, _username, _password: ("2026-08-31", "2026-11-08", 10),
    )

    response = TestClient(create_app()).post(
        "/api/v1/admin/monitor/calendar/refresh",
        headers={"X-Admin-Token": "secret"},
    )

    assert response.status_code == 200
    assert response.json()["total_weeks"] == 18
    assert response.json()["semester_end_date"] == "2027-01-03"


def test_calendar_refresh_records_a_safe_error_for_existing_calendar(monkeypatch):
    from app.modules.connectors.hue_connector import HUEConnector

    monkeypatch.setenv("ADMIN_TOKEN", "secret")
    monkeypatch.setenv("ACADEMIC_CALENDAR_PROBE_USERNAME", "calendar-probe")
    monkeypatch.setenv("ACADEMIC_CALENDAR_PROBE_PASSWORD", "calendar-password")
    get_settings.cache_clear()
    monkeypatch.setattr(
        HUEConnector,
        "fetch_academic_calendar",
        lambda _self, _username, _password: ("2026-08-31", "2027-01-31", 22),
    )
    client = TestClient(create_app())
    headers = {"X-Admin-Token": "secret"}
    assert client.post("/api/v1/admin/monitor/calendar/refresh", headers=headers).status_code == 200

    def fail_calendar_fetch(_self, _username, _password):
        raise RuntimeError("HUE schedule preview is unavailable")

    monkeypatch.setattr(HUEConnector, "fetch_academic_calendar", fail_calendar_fetch)
    assert client.post("/api/v1/admin/monitor/calendar/refresh", headers=headers).status_code == 503

    calendar = client.get("/api/v1/admin/monitor/calendar", headers=headers).json()["calendar"]
    assert calendar["last_error"] == "HUE schedule preview is unavailable"


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

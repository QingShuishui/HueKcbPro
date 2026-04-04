from datetime import datetime, timedelta, timezone

from fastapi.testclient import TestClient

from app.core.db import SessionLocal
from app.main import create_app
from app.modules.connectors.base import NormalizedCourse, NormalizedSchedule
from app.modules.schedule import cache as schedule_cache


def test_login_writes_schedule_cache(monkeypatch):
    from app.modules.auth import service as auth_service

    def fake_fetch_schedule(self, username: str, password: str):
        return NormalizedSchedule(
            semester_label="2026春",
            generated_at="2026-04-04T10:00:00Z",
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

    monkeypatch.setattr(auth_service.HUEConnector, "fetch_schedule", fake_fetch_schedule)
    client = TestClient(create_app())
    login_response = client.post(
        "/api/v1/auth/login",
        json={
            "school_code": "hue",
            "academic_username": "demo_student_id",
            "password": "pw123",
            "device_name": "Pixel",
        },
    )

    user_id = login_response.json()["user"]["id"]
    cached = schedule_cache.get_cached_schedule(user_id)

    assert cached is not None
    assert cached["semester_label"] == "2026春"


def test_current_schedule_repopulates_cache_from_snapshot_when_cache_missing(
    monkeypatch,
):
    from app.modules.auth import service as auth_service

    def fake_fetch_schedule(self, username: str, password: str):
        return NormalizedSchedule(
            semester_label="2026春",
            generated_at="2026-04-04T10:00:00Z",
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

    monkeypatch.setattr(auth_service.HUEConnector, "fetch_schedule", fake_fetch_schedule)
    client = TestClient(create_app())
    login_response = client.post(
        "/api/v1/auth/login",
        json={
            "school_code": "hue",
            "academic_username": "demo_student_id",
            "password": "pw123",
            "device_name": "Pixel",
        },
    )
    user_id = login_response.json()["user"]["id"]
    access_token = login_response.json()["access_token"]

    schedule_cache.delete_cached_schedule(user_id)
    assert schedule_cache.get_cached_schedule(user_id) is None

    response = client.get(
        "/api/v1/schedule/current",
        headers={"Authorization": f"Bearer {access_token}"},
    )

    assert response.status_code == 200
    assert schedule_cache.get_cached_schedule(user_id) is not None


def test_current_schedule_marks_payload_stale_when_cache_expired(monkeypatch):
    from app.modules.auth import service as auth_service
    from app.models.academic_binding import AcademicBinding

    def fake_fetch_schedule(self, username: str, password: str):
        return NormalizedSchedule(
            semester_label="2026春",
            generated_at="2026-04-04T10:00:00Z",
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

    monkeypatch.setattr(auth_service.HUEConnector, "fetch_schedule", fake_fetch_schedule)
    client = TestClient(create_app())
    login_response = client.post(
        "/api/v1/auth/login",
        json={
            "school_code": "hue",
            "academic_username": "demo_student_id",
            "password": "pw123",
            "device_name": "Pixel",
        },
    )
    user_id = login_response.json()["user"]["id"]
    access_token = login_response.json()["access_token"]

    with SessionLocal() as db:
        binding = db.query(AcademicBinding).filter_by(user_id=user_id).one()
        binding.sync_state.cache_expires_at = (
            datetime.now(timezone.utc) - timedelta(minutes=5)
        ).isoformat()
        db.commit()

    schedule_cache.delete_cached_schedule(user_id)
    response = client.get(
        "/api/v1/schedule/current",
        headers={"Authorization": f"Bearer {access_token}"},
    )

    assert response.status_code == 200
    assert response.json()["is_stale"] is True

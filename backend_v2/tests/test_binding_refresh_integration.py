from datetime import datetime, timezone

from fastapi.testclient import TestClient

from app.core.db import SessionLocal
from app.core.security import create_access_token
from app.main import create_app
from app.models.academic_binding import AcademicBinding
from app.models.schedule_snapshot import ScheduleSnapshot
from app.models.user import User
from app.modules.connectors.base import NormalizedCourse, NormalizedSchedule


def test_bind_route_persists_binding_for_authenticated_user(monkeypatch):
    from app.modules.credentials import service as credentials_service

    def fake_fetch_schedule(self, username: str, password: str):
        return NormalizedSchedule(
            semester_label="2026春",
            generated_at=datetime.now(timezone.utc).isoformat(),
            courses=[
                NormalizedCourse(
                    name="数据库原理",
                    code="SJK",
                    teacher="李四",
                    room="S3301",
                    weekday=2,
                    lesson_start=3,
                    lesson_end=4,
                    raw_weeks="1-16(周)",
                    parsed_weeks=[1, 2, 3],
                )
            ],
        )

    monkeypatch.setattr(
        credentials_service.HUEConnector,
        "fetch_schedule",
        fake_fetch_schedule,
    )

    with SessionLocal() as db:
        user = User(display_name="tester", last_login_at=None)
        db.add(user)
        db.commit()
        db.refresh(user)
        user_id = user.id

    client = TestClient(create_app())
    response = client.post(
        "/api/v1/jw/bind",
        headers={"Authorization": f"Bearer {create_access_token(user_id)}"},
        json={
            "school_code": "hue",
            "academic_username": "demo_student_id",
            "password": "pw123",
        },
    )

    assert response.status_code == 200
    with SessionLocal() as db:
        binding = db.query(AcademicBinding).one()
        assert binding.user_id == user_id
        assert db.query(ScheduleSnapshot).count() == 1


def test_refresh_endpoint_updates_existing_snapshot(monkeypatch):
    from app.modules.auth import service as auth_service
    from app.modules.tasks import schedule_tasks

    def initial_schedule(self, username: str, password: str):
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

    def refreshed_schedule(self, username: str, password: str):
        return NormalizedSchedule(
            semester_label="2026春",
            generated_at="2026-04-05T10:00:00Z",
            courses=[
                NormalizedCourse(
                    name="编译原理",
                    code="BYYL",
                    teacher="王五",
                    room="S2202",
                    weekday=3,
                    lesson_start=5,
                    lesson_end=6,
                    raw_weeks="1-16(周)",
                    parsed_weeks=[1, 2, 3],
                )
            ],
        )

    monkeypatch.setattr(auth_service.HUEConnector, "fetch_schedule", initial_schedule)
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
    access_token = login_response.json()["access_token"]

    monkeypatch.setattr(
        schedule_tasks.HUEConnector,
        "fetch_schedule",
        refreshed_schedule,
    )
    refresh_response = client.post(
        "/api/v1/schedule/refresh",
        headers={"Authorization": f"Bearer {access_token}"},
    )

    assert refresh_response.status_code == 202

    current_response = client.get(
        "/api/v1/schedule/current",
        headers={"Authorization": f"Bearer {access_token}"},
    )

    assert current_response.status_code == 200
    assert current_response.json()["courses"][0]["name"] == "编译原理"

from datetime import datetime, timezone

from fastapi.testclient import TestClient

from app.core.db import SessionLocal
from app.main import create_app
from app.models.academic_binding import AcademicBinding
from app.models.encrypted_credential import EncryptedCredential
from app.models.schedule_snapshot import ScheduleSnapshot
from app.models.user import User
from app.modules.connectors.base import NormalizedCourse, NormalizedSchedule


def test_login_persists_user_binding_and_schedule_snapshot(monkeypatch):
    from app.modules.auth import service as auth_service

    def fake_fetch_schedule(self, username: str, password: str):
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

    monkeypatch.setattr(
        auth_service.HUEConnector,
        "fetch_schedule",
        fake_fetch_schedule,
    )

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

    with SessionLocal() as db:
        assert db.query(User).count() == 1
        binding = db.query(AcademicBinding).one()
        assert binding.academic_username == "demo_student_id"
        assert db.query(EncryptedCredential).count() == 1
        assert db.query(ScheduleSnapshot).count() == 1


def test_current_schedule_returns_persisted_snapshot_for_authenticated_user(
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

    monkeypatch.setattr(
        auth_service.HUEConnector,
        "fetch_schedule",
        fake_fetch_schedule,
    )

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

    response = client.get(
        "/api/v1/schedule/current",
        headers={"Authorization": f"Bearer {access_token}"},
    )

    assert response.status_code == 200
    assert response.json()["semester_label"] == "2026春"
    assert response.json()["courses"][0]["name"] == "软件测试技术"
    assert response.json()["courses"][0]["code"] == "SIT"

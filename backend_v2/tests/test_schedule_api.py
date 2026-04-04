from fastapi.testclient import TestClient

from app.core.security import create_access_token
from app.main import create_app


def test_current_schedule_returns_stale_payload_when_cache_exists(monkeypatch):
    from app.modules.schedule import router as schedule_router

    monkeypatch.setattr(
        schedule_router,
        "read_current_schedule",
        lambda user_id: {
            "semester_label": "2026春",
            "generated_at": "2026-04-04T10:00:00Z",
            "is_stale": True,
            "last_synced_at": "2026-04-04T08:00:00Z",
            "courses": [],
        },
    )

    client = TestClient(create_app())
    response = client.get(
        "/api/v1/schedule/current",
        headers={"Authorization": f"Bearer {create_access_token(1)}"},
    )

    assert response.status_code == 200
    assert response.json()["is_stale"] is True


def test_current_schedule_returns_course_code(monkeypatch):
    from app.modules.schedule import router as schedule_router

    monkeypatch.setattr(
        schedule_router,
        "read_current_schedule",
        lambda user_id: {
            "semester_label": "2026春",
            "generated_at": "2026-04-04T10:00:00Z",
            "is_stale": False,
            "last_synced_at": "2026-04-04T08:00:00Z",
            "courses": [
                {
                    "name": "软件测试技术",
                    "code": "SIT",
                    "teacher": "张三",
                    "room": "S4409",
                    "weekday": 1,
                    "lesson_start": 1,
                    "lesson_end": 2,
                    "raw_weeks": "1-16(周)",
                    "parsed_weeks": [1, 2, 3],
                }
            ],
        },
    )

    client = TestClient(create_app())
    response = client.get(
        "/api/v1/schedule/current",
        headers={"Authorization": f"Bearer {create_access_token(1)}"},
    )

    assert response.status_code == 200
    assert response.json()["courses"][0]["code"] == "SIT"


def test_status_endpoint_returns_sync_metadata(monkeypatch):
    from app.modules.schedule import router as schedule_router

    monkeypatch.setattr(
        schedule_router,
        "read_sync_status",
        lambda user_id: {
            "sync_status": "synced",
            "schedule_version": 3,
            "last_sync_error": None,
        },
    )

    client = TestClient(create_app())
    response = client.get(
        "/api/v1/schedule/status",
        headers={"Authorization": f"Bearer {create_access_token(1)}"},
    )

    assert response.status_code == 200
    assert response.json()["schedule_version"] == 3

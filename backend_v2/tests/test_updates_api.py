from fastapi.testclient import TestClient

from app.main import create_app


def test_android_update_endpoint_returns_release_payload(monkeypatch):
    from app.modules.updates import router as updates_router

    monkeypatch.setattr(
        updates_router,
        "read_latest_android_release",
        lambda: {
            "platform": "android",
            "version": "1.0.1",
            "build_number": 2,
            "force_update": False,
            "notes": "Schedule polish",
            "apk_url": "https://example.com/app.apk",
            "sha256": "abc",
            "published_at": "2026-04-04T10:00:00Z",
        },
    )

    client = TestClient(create_app())
    response = client.get("/api/v1/app/update/android")

    assert response.status_code == 200
    assert response.json()["build_number"] == 2

from fastapi.testclient import TestClient

from app.main import create_app
from pathlib import Path


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
            "primary_apk_url": "https://example.com/app.apk",
            "fallback_apk_url": "https://api.example.com/downloads/app.apk",
            "sha256": "abc",
            "published_at": "2026-04-04T10:00:00Z",
        },
    )

    client = TestClient(create_app())
    response = client.get("/api/v1/app/update/android")

    assert response.status_code == 200
    assert response.json()["build_number"] == 2
    assert response.json()["fallback_apk_url"] == "https://api.example.com/downloads/app.apk"


def test_android_update_endpoint_returns_404_when_no_release(monkeypatch):
    from app.modules.updates import router as updates_router
    from fastapi import HTTPException, status

    def _missing_release():
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="no android release metadata",
        )

    monkeypatch.setattr(updates_router, "read_latest_android_release", _missing_release)

    client = TestClient(create_app())
    response = client.get("/api/v1/app/update/android")

    assert response.status_code == 404


def test_android_download_endpoint_serves_apk(monkeypatch, tmp_path):
    from app.modules.updates import router as updates_router

    apk = tmp_path / "HueKcbPro-1.0.2+12.apk"
    apk.write_bytes(b"apk-binary")
    monkeypatch.setattr(updates_router, "DOWNLOADS_DIR", tmp_path)

    client = TestClient(create_app())
    response = client.get("/api/v1/app/update/downloads/HueKcbPro-1.0.2+12.apk")

    assert response.status_code == 200
    assert response.content == b"apk-binary"

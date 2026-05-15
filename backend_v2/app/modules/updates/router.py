import json
from pathlib import Path

from fastapi import APIRouter, HTTPException, status
from fastapi.responses import FileResponse


router = APIRouter(prefix="/api/v1/app/update", tags=["updates"])
BASE_DIR = Path(__file__).resolve().parents[3]
LATEST_ANDROID_JSON = BASE_DIR / "storage" / "latest-android.json"
DOWNLOADS_DIR = BASE_DIR / "downloads"


def read_latest_android_release() -> dict:
    if not LATEST_ANDROID_JSON.exists():
      raise HTTPException(
          status_code=status.HTTP_404_NOT_FOUND,
          detail="no android release metadata",
      )

    try:
        payload = json.loads(LATEST_ANDROID_JSON.read_text(encoding="utf-8"))
    except json.JSONDecodeError as error:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="android release metadata is invalid",
        ) from error

    if not payload:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="no android release metadata",
        )

    payload.setdefault("primary_apk_url", "")
    payload.setdefault("fallback_apk_url", "")
    if "apk_url" in payload and not payload["fallback_apk_url"]:
        payload["fallback_apk_url"] = payload["apk_url"]
    payload.pop("apk_url", None)

    return payload


@router.get("/android")
def latest_android_release() -> dict:
    return read_latest_android_release()


def _download_android_release_response(filename: str) -> FileResponse:
    file_path = (DOWNLOADS_DIR / filename).resolve()
    downloads_root = DOWNLOADS_DIR.resolve()
    if downloads_root not in file_path.parents or not file_path.exists():
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="apk not found",
        )

    return FileResponse(
        file_path,
        media_type="application/vnd.android.package-archive",
        filename=file_path.name,
    )


@router.get("/downloads/{filename}")
def download_android_release(filename: str) -> FileResponse:
    return _download_android_release_response(filename)


@router.head("/downloads/{filename}")
def head_android_release(filename: str) -> FileResponse:
    return _download_android_release_response(filename)

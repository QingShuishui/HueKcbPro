from fastapi import APIRouter


router = APIRouter(prefix="/api/v1/app/update", tags=["updates"])


def read_latest_android_release() -> dict:
    return {
        "platform": "android",
        "version": "1.0.0",
        "build_number": 1,
        "force_update": False,
        "notes": "",
        "apk_url": "",
        "sha256": "",
        "published_at": "1970-01-01T00:00:00Z",
    }


@router.get("/android")
def latest_android_release() -> dict:
    return read_latest_android_release()

import json
from datetime import datetime, timezone

from fastapi import APIRouter, Depends, status

from app.core.db import SessionLocal
from app.core.security import get_current_user_id
from app.models.academic_binding import AcademicBinding
from app.models.schedule_snapshot import ScheduleSnapshot
from app.modules.schedule.cache import get_cached_schedule, set_cached_schedule
from app.modules.tasks.schedule_tasks import sync_schedule


router = APIRouter(prefix="/api/v1/schedule", tags=["schedule"])


def read_current_schedule(user_id: int) -> dict:
    cached = get_cached_schedule(user_id)
    if cached is not None:
        cache_expires_at = cached.get("cache_expires_at")
        is_stale = False
        if cache_expires_at is not None:
            is_stale = (
                datetime.now(timezone.utc) > datetime.fromisoformat(cache_expires_at)
            )
        return {
            "semester_label": cached["semester_label"],
            "generated_at": cached["generated_at"],
            "is_stale": is_stale,
            "last_synced_at": cached.get("last_synced_at"),
            "courses": cached["courses"],
        }

    with SessionLocal() as db:
        binding = db.query(AcademicBinding).filter_by(user_id=user_id).one_or_none()
        if binding is None or binding.sync_state is None:
            return {"code": "SYNC_IN_PROGRESS", "status": "queued", "courses": []}

        current_snapshot_id = binding.sync_state.current_snapshot_id
        if current_snapshot_id is None:
            return {"code": "SYNC_IN_PROGRESS", "status": "queued", "courses": []}

        snapshot = db.get(ScheduleSnapshot, current_snapshot_id)
        if snapshot is None:
            return {"code": "SYNC_IN_PROGRESS", "status": "queued", "courses": []}
        payload = json.loads(snapshot.payload_json)
        cache_expires_at = binding.sync_state.cache_expires_at
        is_stale = False
        if cache_expires_at is not None:
            is_stale = (
                datetime.now(timezone.utc) > datetime.fromisoformat(cache_expires_at)
            )
        cache_payload = {
            "semester_label": payload["semester_label"],
            "generated_at": payload["generated_at"],
            "is_stale": is_stale,
            "last_synced_at": binding.sync_state.last_synced_at,
            "cache_expires_at": cache_expires_at,
            "courses": payload["courses"],
        }
        set_cached_schedule(user_id, cache_payload)
        return {
            "semester_label": cache_payload["semester_label"],
            "generated_at": cache_payload["generated_at"],
            "is_stale": cache_payload["is_stale"],
            "last_synced_at": cache_payload["last_synced_at"],
            "courses": cache_payload["courses"],
        }


def read_sync_status(user_id: int) -> dict:
    with SessionLocal() as db:
        binding = db.query(AcademicBinding).filter_by(user_id=user_id).one_or_none()
        if binding is None or binding.sync_state is None:
            return {
                "sync_status": "never_synced",
                "schedule_version": 0,
                "last_sync_error": None,
            }

        return {
            "sync_status": binding.sync_state.sync_status,
            "schedule_version": binding.sync_state.schedule_version,
            "last_sync_error": binding.sync_state.last_sync_error,
        }


@router.get("/current")
def current_schedule(user_id: int = Depends(get_current_user_id)) -> dict:
    return read_current_schedule(user_id=user_id)


@router.get("/status")
def sync_status(user_id: int = Depends(get_current_user_id)) -> dict:
    return read_sync_status(user_id=user_id)


@router.post("/refresh", status_code=status.HTTP_202_ACCEPTED)
def refresh_schedule(user_id: int = Depends(get_current_user_id)) -> dict:
    with SessionLocal() as db:
        binding = db.query(AcademicBinding).filter_by(user_id=user_id).one_or_none()
        binding_id = binding.id if binding else 1
    sync_schedule.delay(binding_id=binding_id)
    return {"code": "SYNC_IN_PROGRESS", "status": "queued"}

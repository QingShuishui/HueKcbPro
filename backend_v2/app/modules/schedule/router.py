import json
import time
from datetime import datetime, timedelta, timezone

from fastapi import APIRouter, Depends, status

from app.core.settings import get_settings
from app.core.db import SessionLocal
from app.core.security import get_current_user_id
from app.models.academic_binding import AcademicBinding
from app.models.schedule_snapshot import ScheduleSnapshot
from app.modules.calendar.service import get_current_academic_calendar
from app.modules.admin.monitoring import record_schedule_log
from app.modules.schedule.cache import get_cached_schedule, set_cached_schedule
from app.modules.tasks.schedule_tasks import sync_schedule


router = APIRouter(prefix="/api/v1/schedule", tags=["schedule"])


def _semester_start_date(payload: dict | None = None) -> str:
    if payload is not None:
        value = payload.get("semester_start_date")
        if value:
            return value
    return get_settings().academic_semester_start_date


def _total_weeks(payload: dict | None = None) -> int:
    value = payload.get("total_weeks") if payload is not None else None
    try:
        return max(int(value or 18), 18)
    except (TypeError, ValueError):
        return 18


def _semester_end_date(semester_start_date: str, total_weeks: int) -> str:
    return (
        datetime.strptime(semester_start_date, "%Y-%m-%d").date()
        + timedelta(days=total_weeks * 7 - 1)
    ).isoformat()


def _current_week(semester_start_date: str, total_weeks: int) -> int:
    start_date = datetime.strptime(semester_start_date, "%Y-%m-%d").date()
    today = datetime.now(timezone(timedelta(hours=8))).date()
    days_diff = (today - start_date).days
    if days_diff < 0:
        return 1
    return min((days_diff // 7) + 1, total_weeks)


def _schedule_response_payload(payload: dict, *, calendar: dict | None = None) -> dict:
    calendar = calendar if calendar is not None else get_current_academic_calendar()
    semester_start_date = (
        calendar["semester_start_date"]
        if calendar is not None
        else _semester_start_date(payload)
    )
    total_weeks = (
        max(int(calendar["total_weeks"]), 18)
        if calendar is not None
        else _total_weeks(payload)
    )
    return {
        "semester_label": payload["semester_label"],
        "semester_start_date": semester_start_date,
        "semester_end_date": (
            calendar["semester_end_date"]
            if calendar is not None
            else payload.get("semester_end_date")
            or _semester_end_date(semester_start_date, total_weeks)
        ),
        "total_weeks": total_weeks,
        "current_week": _current_week(semester_start_date, total_weeks),
        "generated_at": payload["generated_at"],
        "is_stale": payload["is_stale"],
        "last_synced_at": payload.get("last_synced_at"),
        "courses": payload["courses"],
    }


def read_current_schedule(user_id: int) -> dict:
    calendar = get_current_academic_calendar()
    cached = get_cached_schedule(user_id)
    if cached is not None:
        cache_expires_at = cached.get("cache_expires_at")
        is_stale = False
        if cache_expires_at is not None:
            is_stale = (
                datetime.now(timezone.utc) > datetime.fromisoformat(cache_expires_at)
            )
        return _schedule_response_payload({
            "semester_label": cached["semester_label"],
            "semester_start_date": (
                calendar["semester_start_date"]
                if calendar is not None
                else _semester_start_date(cached)
            ),
            "semester_end_date": (
                calendar["semester_end_date"]
                if calendar is not None
                else cached.get("semester_end_date")
            ),
            "total_weeks": (
                calendar["total_weeks"]
                if calendar is not None
                else cached.get("total_weeks")
            ),
            "generated_at": cached["generated_at"],
            "is_stale": is_stale,
            "last_synced_at": cached.get("last_synced_at"),
            "courses": cached["courses"],
        }, calendar=calendar)

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
            "semester_start_date": (
                calendar["semester_start_date"]
                if calendar is not None
                else _semester_start_date(payload)
            ),
            "semester_end_date": (
                calendar["semester_end_date"]
                if calendar is not None
                else payload.get("semester_end_date")
            ),
            "total_weeks": (
                calendar["total_weeks"]
                if calendar is not None
                else payload.get("total_weeks")
            ),
            "generated_at": payload["generated_at"],
            "is_stale": is_stale,
            "last_synced_at": binding.sync_state.last_synced_at,
            "cache_expires_at": cache_expires_at,
            "courses": payload["courses"],
        }
        set_cached_schedule(user_id, cache_payload)
        return _schedule_response_payload(cache_payload, calendar=calendar)


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
    start = time.perf_counter()
    try:
        result = read_current_schedule(user_id=user_id)
        record_schedule_log(
            user_id=user_id,
            action="current",
            status="success",
            duration_ms=int((time.perf_counter() - start) * 1000),
        )
        return result
    except Exception as exc:
        record_schedule_log(
            user_id=user_id,
            action="current",
            status="error",
            duration_ms=int((time.perf_counter() - start) * 1000),
            error_message=str(exc)[:500],
        )
        raise


@router.get("/status")
def sync_status(user_id: int = Depends(get_current_user_id)) -> dict:
    return read_sync_status(user_id=user_id)


@router.post("/refresh", status_code=status.HTTP_202_ACCEPTED)
def refresh_schedule(user_id: int = Depends(get_current_user_id)) -> dict:
    start = time.perf_counter()
    with SessionLocal() as db:
        binding = db.query(AcademicBinding).filter_by(user_id=user_id).one_or_none()
        binding_id = binding.id if binding else 1
    sync_schedule.delay(binding_id=binding_id)
    record_schedule_log(
        user_id=user_id,
        action="refresh",
        status="queued",
        duration_ms=int((time.perf_counter() - start) * 1000),
    )
    return {"code": "SYNC_IN_PROGRESS", "status": "queued"}

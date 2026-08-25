from datetime import date, datetime, timedelta, timezone
from threading import Lock

from app.core.db import SessionLocal
from app.core.settings import get_settings
from app.models.semester_calendar import SemesterCalendar


_calendar_cache: dict[str, dict] = {}
_calendar_refresh_lock = Lock()


def _serialize(calendar: SemesterCalendar) -> dict:
    return {
        "term_id": calendar.term_id,
        "semester_start_date": calendar.semester_start_date,
        "semester_end_date": calendar.semester_end_date,
        "total_weeks": calendar.total_weeks,
        "detected_at": calendar.detected_at,
        "last_error": calendar.last_error,
    }


def get_current_academic_calendar(db=None) -> dict | None:
    term_id = get_settings().academic_term_id
    if db is not None:
        calendar = db.get(SemesterCalendar, term_id)
        return _serialize(calendar) if calendar is not None else None
    cached = _calendar_cache.get(term_id)
    if cached is not None:
        return cached.copy()
    with SessionLocal() as db:
        calendar = db.get(SemesterCalendar, term_id)
        if calendar is None:
            return None
        payload = _serialize(calendar)
        _calendar_cache[term_id] = payload
        return payload.copy()


def _safe_error_message(error: Exception, settings) -> str:
    message = str(error)
    for secret in (
        settings.academic_calendar_probe_username,
        settings.academic_calendar_probe_password,
    ):
        if secret:
            message = message.replace(secret, "[redacted]")
    return message[:500] or error.__class__.__name__


def _record_refresh_error(*, term_id: str, message: str) -> None:
    with SessionLocal() as db:
        calendar = db.get(SemesterCalendar, term_id)
        if calendar is None:
            return
        calendar.last_error = message
        db.commit()
        db.refresh(calendar)
        _calendar_cache[term_id] = _serialize(calendar)


def refresh_current_academic_calendar() -> dict:
    settings = get_settings()
    if not settings.academic_calendar_probe_username or not settings.academic_calendar_probe_password:
        raise RuntimeError("academic calendar probe credentials are not configured")

    # Imported here so normal schedule reads do not create a connector dependency cycle.
    from app.modules.connectors.hue_connector import HUEConnector

    # A refresh fetches remote HUE data before inserting the term row. Serialize it
    # within a process so simultaneous admin clicks cannot race the primary key.
    with _calendar_refresh_lock:
        try:
            start_date, _end_date, total_weeks = HUEConnector().fetch_academic_calendar(
                settings.academic_calendar_probe_username,
                settings.academic_calendar_probe_password,
            )
        except Exception as error:
            _record_refresh_error(
                term_id=settings.academic_term_id,
                message=_safe_error_message(error, settings),
            )
            raise

        total_weeks = max(int(total_weeks), 18)
        end_date = (
            date.fromisoformat(start_date) + timedelta(days=total_weeks * 7 - 1)
        ).isoformat()
        detected_at = datetime.now(timezone.utc).isoformat()
        with SessionLocal() as db:
            calendar = db.get(SemesterCalendar, settings.academic_term_id)
            if calendar is None:
                calendar = SemesterCalendar(
                    term_id=settings.academic_term_id,
                    semester_start_date=start_date,
                    semester_end_date=end_date,
                    total_weeks=total_weeks,
                    detected_at=detected_at,
                    last_error=None,
                )
                db.add(calendar)
            else:
                calendar.semester_start_date = start_date
                calendar.semester_end_date = end_date
                calendar.total_weeks = total_weeks
                calendar.detected_at = detected_at
                calendar.last_error = None
            db.commit()
            db.refresh(calendar)
            payload = _serialize(calendar)
            _calendar_cache[settings.academic_term_id] = payload
            return payload.copy()


def clear_academic_calendar_cache() -> None:
    _calendar_cache.clear()


def ensure_current_academic_calendar() -> dict | None:
    calendar = get_current_academic_calendar()
    return calendar if calendar is not None else refresh_current_academic_calendar()

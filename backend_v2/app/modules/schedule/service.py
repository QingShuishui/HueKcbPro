from datetime import date, timedelta

from app.core.settings import get_settings
from app.modules.schedule.hash import compute_schedule_hash


def normalize_connector_schedule(connector_result) -> dict:
    settings = get_settings()
    semester_start_date = (
        connector_result.semester_start_date
        or settings.academic_semester_start_date
    )
    total_weeks = max(int(connector_result.total_weeks or 18), 18)
    semester_end_date = connector_result.semester_end_date
    if semester_end_date is None:
        semester_end_date = (
            date.fromisoformat(semester_start_date)
            + timedelta(days=total_weeks * 7 - 1)
        ).isoformat()
    payload = {
        "semester_label": connector_result.semester_label,
        "semester_start_date": semester_start_date,
        "semester_end_date": semester_end_date,
        "total_weeks": total_weeks,
        "generated_at": connector_result.generated_at,
        "courses": [
            {
                "name": course.name,
                "code": course.code,
                "teacher": course.teacher,
                "room": course.room,
                "weekday": course.weekday,
                "lesson_start": course.lesson_start,
                "lesson_end": course.lesson_end,
                "raw_weeks": course.raw_weeks,
                "parsed_weeks": course.parsed_weeks,
            }
            for course in connector_result.courses
        ],
    }
    payload["schedule_hash"] = compute_schedule_hash(payload)
    return payload

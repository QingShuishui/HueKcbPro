from app.modules.schedule.hash import compute_schedule_hash


def normalize_connector_schedule(connector_result) -> dict:
    payload = {
        "semester_label": connector_result.semester_label,
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

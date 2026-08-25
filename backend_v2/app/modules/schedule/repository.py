def serialize_snapshot(payload: dict) -> dict:
    return {
        "semester_label": payload["semester_label"],
        "semester_start_date": payload.get("semester_start_date"),
        "semester_end_date": payload.get("semester_end_date"),
        "total_weeks": payload.get("total_weeks"),
        "generated_at": payload["generated_at"],
        "schedule_hash": payload["schedule_hash"],
        "courses": payload["courses"],
    }

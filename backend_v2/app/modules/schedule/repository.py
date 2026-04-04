def serialize_snapshot(payload: dict) -> dict:
    return {
        "semester_label": payload["semester_label"],
        "generated_at": payload["generated_at"],
        "schedule_hash": payload["schedule_hash"],
        "courses": payload["courses"],
    }

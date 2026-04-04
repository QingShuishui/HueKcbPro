from app.modules.schedule.hash import compute_schedule_hash


def test_schedule_hash_is_stable_for_equal_payloads():
    payload = {
        "semester_label": "2026春",
        "courses": [
            {
                "name": "软件测试技术",
                "teacher": "张三",
                "room": "S4409",
                "weekday": 1,
                "lesson_start": 1,
                "lesson_end": 2,
                "raw_weeks": "1-16(周)",
                "parsed_weeks": [1, 2, 3],
            }
        ],
    }

    assert compute_schedule_hash(payload) == compute_schedule_hash(payload)

from unittest.mock import patch


@patch("app.decrypt_password", return_value="pw123")
@patch(
    "app.login_and_get_schedule",
    return_value=({"courses": [], "semester_info": "2026春", "generated_at": "now"}, None),
)
@patch("app.get_current_week", return_value=6)
def test_schedule_api_uses_token_semester_start_date(
    _current_week, _crawler, _decrypt_password, client
):
    from app import credential_store

    credential_store.save_record(
        token="Ab3X9kQ2",
        username="demo_student_id",
        encrypted_password="ciphertext",
        created_at="2026-03-31T12:00:00",
        last_accessed_at="2026-03-31T12:00:00",
    )
    credential_store.update_record_settings(
        token="Ab3X9kQ2",
        username="demo_student_id",
        encrypted_password="ciphertext",
        semester_start_date="2026-02-24",
    )

    response = client.get("/api/schedule/Ab3X9kQ2")

    assert response.status_code == 200
    _current_week.assert_called_with("2026-02-24")
    assert response.get_json()["selected_week"] == 6


@patch("app.decrypt_password", return_value="pw123")
@patch(
    "app.login_and_get_schedule",
    return_value=({"courses": [], "semester_info": "2026春", "generated_at": "now"}, None),
)
def test_schedule_api_uses_token_record(_crawler, _decrypt_password, client):
    from app import credential_store

    credential_store.save_record(
        token="Ab3X9kQ2",
        username="demo_student_id",
        encrypted_password="ciphertext",
        created_at="2026-03-31T12:00:00",
        last_accessed_at="2026-03-31T12:00:00",
    )

    response = client.get("/api/schedule/Ab3X9kQ2")

    assert response.status_code == 200
    _crawler.assert_called_once_with("demo_student_id", "pw123")


def test_schedule_api_rejects_missing_token(client):
    response = client.get("/api/schedule/Missing1")

    assert response.status_code == 404
    assert response.get_json()["error"] == "链接无效，请重新登录"


@patch("app.decrypt_password", return_value="pw123")
@patch(
    "app.login_and_get_schedule",
    return_value=({"courses": [], "semester_info": "2026春", "generated_at": "now"}, None),
)
def test_schedule_api_rejects_invalid_week_param(_crawler, _decrypt_password, client):
    from app import credential_store

    credential_store.save_record(
        token="Ab3X9kQ2",
        username="demo_student_id",
        encrypted_password="ciphertext",
        created_at="2026-03-31T12:00:00",
        last_accessed_at="2026-03-31T12:00:00",
    )

    response = client.get("/api/schedule/Ab3X9kQ2?week=abc")

    assert response.status_code == 400
    assert response.get_json()["error"] == "周次参数无效"


@patch("app.decrypt_password", return_value="pw123")
@patch(
    "app.login_and_get_schedule",
    return_value=({"courses": [], "semester_info": "2026春", "generated_at": "now"}, None),
)
def test_schedule_api_supports_all_week_mode(_crawler, _decrypt_password, client):
    from app import credential_store

    credential_store.save_record(
        token="Ab3X9kQ2",
        username="demo_student_id",
        encrypted_password="ciphertext",
        created_at="2026-03-31T12:00:00",
        last_accessed_at="2026-03-31T12:00:00",
    )

    response = client.get("/api/schedule/Ab3X9kQ2?week=all")

    assert response.status_code == 200
    assert response.get_json()["selected_week"] is None

def test_get_settings_api_returns_current_token_settings(client):
    from app import credential_store, encrypt_password

    credential_store.save_record(
        token="Ab3X9kQ2",
        username="demo_student_id",
        encrypted_password=encrypt_password("pw123"),
        created_at="2026-03-31T12:00:00",
        last_accessed_at="2026-03-31T12:00:00",
    )

    response = client.get("/api/tokens/Ab3X9kQ2/settings")

    assert response.status_code == 200
    assert response.get_json()["username"] == "demo_student_id"
    assert response.get_json()["password"] == "pw123"
    assert response.get_json()["semester_start_date"] == "2026-03-02"
    assert response.get_json()["saved_link"].endswith("/t/Ab3X9kQ2")


def test_patch_settings_api_updates_current_token_settings(client):
    from app import credential_store, decrypt_password

    credential_store.save_record(
        token="Ab3X9kQ2",
        username="demo_student_id",
        encrypted_password="ciphertext",
        created_at="2026-03-31T12:00:00",
        last_accessed_at="2026-03-31T12:00:00",
    )

    response = client.patch(
        "/api/tokens/Ab3X9kQ2/settings",
        json={
            "username": "20260001",
            "password": "newpass",
            "semester_start_date": "2026-02-24",
        },
    )

    assert response.status_code == 200
    updated = credential_store.get_record("Ab3X9kQ2")
    assert updated["username"] == "20260001"
    assert decrypt_password(updated["encrypted_password"]) == "newpass"
    assert updated["semester_start_date"] == "2026-02-24"


def test_patch_settings_api_rejects_invalid_date(client):
    from app import credential_store

    credential_store.save_record(
        token="Ab3X9kQ2",
        username="demo_student_id",
        encrypted_password="ciphertext",
        created_at="2026-03-31T12:00:00",
        last_accessed_at="2026-03-31T12:00:00",
    )

    response = client.patch(
        "/api/tokens/Ab3X9kQ2/settings",
        json={
            "username": "20260001",
            "password": "newpass",
            "semester_start_date": "2026/02/24",
        },
    )

    assert response.status_code == 400
    assert response.get_json()["error"] == "开学日期格式无效"


def test_settings_api_prefers_public_base_url(client, monkeypatch):
    from app import credential_store, encrypt_password

    monkeypatch.setenv("PUBLIC_BASE_URL", "https://kcb.mc91.cn")
    credential_store.save_record(
        token="Ab3X9kQ2",
        username="demo_student_id",
        encrypted_password=encrypt_password("pw123"),
        created_at="2026-03-31T12:00:00",
        last_accessed_at="2026-03-31T12:00:00",
    )

    response = client.get("/api/tokens/Ab3X9kQ2/settings")

    assert response.status_code == 200
    assert response.get_json()["saved_link"] == "https://kcb.mc91.cn/t/Ab3X9kQ2"

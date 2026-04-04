def test_mark_link_hint_seen_api_updates_state(client):
    from app import credential_store

    credential_store.save_record(
        token="Ab3X9kQ2",
        username="demo_student_id",
        encrypted_password="ciphertext",
        created_at="2026-03-31T12:00:00",
        last_accessed_at="2026-03-31T12:00:00",
    )

    response = client.post("/api/tokens/Ab3X9kQ2/link-hint-seen")

    assert response.status_code == 200
    assert response.get_json() == {"ok": True}
    assert credential_store.get_record("Ab3X9kQ2")["link_hint_seen"] == 1

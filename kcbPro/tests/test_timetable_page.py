def test_timetable_page_shows_saved_link_notice(client):
    from app import credential_store

    credential_store.save_record(
        token="Ab3X9kQ2",
        username="demo_student_id",
        encrypted_password="ciphertext",
        created_at="2026-03-31T12:00:00",
        last_accessed_at="2026-03-31T12:00:00",
    )

    response = client.get("/t/Ab3X9kQ2")

    assert "请保存此链接" in response.get_data(as_text=True)
    assert "/t/Ab3X9kQ2" in response.get_data(as_text=True)
    assert 'data-show-link-hint="true"' in response.get_data(as_text=True)
    assert 'id="homeNavTrigger"' in response.get_data(as_text=True)
    assert 'id="mobileSettingsTrigger"' in response.get_data(as_text=True)
    assert 'id="desktopSettingsTrigger"' not in response.get_data(as_text=True)
    assert "分享此课程表" in response.get_data(as_text=True)
    assert "开学日期" in response.get_data(as_text=True)
    assert response.get_data(as_text=True).count('class="nav-item') == 2

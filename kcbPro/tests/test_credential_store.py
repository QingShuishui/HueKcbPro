from utils.credential_store import CredentialStore


def test_store_save_and_get_record(temp_db_path):
    store = CredentialStore(temp_db_path)
    store.initialize()

    store.save_record(
        token="Ab3X9kQ2",
        username="demo_student_id",
        encrypted_password="ciphertext",
        created_at="2026-03-31T12:00:00",
        last_accessed_at="2026-03-31T12:00:00",
    )

    record = store.get_record("Ab3X9kQ2")

    assert record["username"] == "demo_student_id"
    assert record["encrypted_password"] == "ciphertext"
    assert record["semester_start_date"] == "2026-03-02"


def test_touch_record_updates_last_accessed_at(temp_db_path):
    store = CredentialStore(temp_db_path)
    store.initialize()
    store.save_record(
        token="Ab3X9kQ2",
        username="demo_student_id",
        encrypted_password="ciphertext",
        created_at="2026-03-31T12:00:00",
        last_accessed_at="2026-03-31T12:00:00",
    )

    store.touch_record("Ab3X9kQ2", "2026-03-31T13:00:00")
    record = store.get_record("Ab3X9kQ2")

    assert record["last_accessed_at"] == "2026-03-31T13:00:00"


def test_store_defaults_link_hint_seen_to_zero(temp_db_path):
    store = CredentialStore(temp_db_path)
    store.initialize()
    store.save_record(
        token="Ab3X9kQ2",
        username="demo_student_id",
        encrypted_password="ciphertext",
        created_at="2026-03-31T12:00:00",
        last_accessed_at="2026-03-31T12:00:00",
    )

    record = store.get_record("Ab3X9kQ2")

    assert record["link_hint_seen"] == 0


def test_mark_link_hint_seen_updates_record(temp_db_path):
    store = CredentialStore(temp_db_path)
    store.initialize()
    store.save_record(
        token="Ab3X9kQ2",
        username="demo_student_id",
        encrypted_password="ciphertext",
        created_at="2026-03-31T12:00:00",
        last_accessed_at="2026-03-31T12:00:00",
    )

    store.mark_link_hint_seen("Ab3X9kQ2")
    record = store.get_record("Ab3X9kQ2")

    assert record["link_hint_seen"] == 1


def test_update_record_settings_persists_fields(temp_db_path):
    store = CredentialStore(temp_db_path)
    store.initialize()
    store.save_record(
        token="Ab3X9kQ2",
        username="demo_student_id",
        encrypted_password="ciphertext",
        created_at="2026-03-31T12:00:00",
        last_accessed_at="2026-03-31T12:00:00",
    )

    store.update_record_settings(
        token="Ab3X9kQ2",
        username="20260001",
        encrypted_password="newcipher",
        semester_start_date="2026-02-23",
    )
    record = store.get_record("Ab3X9kQ2")

    assert record["username"] == "20260001"
    assert record["encrypted_password"] == "newcipher"
    assert record["semester_start_date"] == "2026-02-23"

import pytest

from utils.crypto import encrypt_password, decrypt_password


def test_encrypt_and_decrypt_password_round_trip(monkeypatch):
    monkeypatch.setenv(
        "CREDENTIAL_ENCRYPTION_KEY",
        "MDEyMzQ1Njc4OWFiY2RlZjAxMjM0NTY3ODlhYmNkZWY="
    )

    encrypted = encrypt_password("secret123")

    assert encrypted != "secret123"
    assert decrypt_password(encrypted) == "secret123"


def test_encrypt_password_requires_env_var(monkeypatch):
    monkeypatch.delenv("CREDENTIAL_ENCRYPTION_KEY", raising=False)

    with pytest.raises(RuntimeError, match="CREDENTIAL_ENCRYPTION_KEY"):
        encrypt_password("secret123")


def test_encrypt_password_requires_valid_key(monkeypatch):
    monkeypatch.setenv("CREDENTIAL_ENCRYPTION_KEY", "not-a-valid-key")

    with pytest.raises(RuntimeError, match="valid Fernet key"):
        encrypt_password("secret123")

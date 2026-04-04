import os

from cryptography.fernet import Fernet


ENV_KEY = "CREDENTIAL_ENCRYPTION_KEY"


def _get_fernet():
    raw_key = os.environ.get(ENV_KEY)
    if not raw_key:
        raise RuntimeError(
            f"{ENV_KEY} must be set and contain the base64-encoded Fernet key."
        )

    try:
        return Fernet(raw_key.encode("utf-8"))
    except (TypeError, ValueError) as exc:
        raise RuntimeError(f"{ENV_KEY} must be a valid Fernet key.") from exc


def encrypt_password(password):
    return _get_fernet().encrypt(password.encode("utf-8")).decode("utf-8")


def decrypt_password(encrypted_password):
    return _get_fernet().decrypt(encrypted_password.encode("utf-8")).decode("utf-8")

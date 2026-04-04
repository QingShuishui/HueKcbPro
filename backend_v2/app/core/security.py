import os
import secrets
from datetime import datetime, timedelta, timezone

from fastapi import Header, HTTPException, status

try:
    import jwt
except ImportError:  # pragma: no cover - fallback for minimal local execution
    jwt = None

from cryptography.fernet import Fernet


JWT_SECRET = os.environ.get("JWT_SECRET", "dev-secret")
CREDENTIAL_ENCRYPTION_KEY = os.environ["CREDENTIAL_ENCRYPTION_KEY"]


def create_access_token(user_id: int) -> str:
    if jwt is None:
        return f"user:{user_id}:{secrets.token_urlsafe(12)}"

    payload = {
        "sub": str(user_id),
        "exp": datetime.now(timezone.utc) + timedelta(hours=2),
    }
    return jwt.encode(payload, JWT_SECRET, algorithm="HS256")


def issue_refresh_token() -> str:
    return secrets.token_urlsafe(32)


def encrypt_password(password: str) -> str:
    return Fernet(CREDENTIAL_ENCRYPTION_KEY.encode("utf-8")).encrypt(
        password.encode("utf-8")
    ).decode("utf-8")


def decrypt_password(encrypted_password: str) -> str:
    return Fernet(CREDENTIAL_ENCRYPTION_KEY.encode("utf-8")).decrypt(
        encrypted_password.encode("utf-8")
    ).decode("utf-8")


def decode_access_token(token: str) -> int:
    if jwt is None:
        if not token.startswith("user:"):
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail="invalid access token",
            )
        return int(token.split(":")[1])

    try:
        payload = jwt.decode(token, JWT_SECRET, algorithms=["HS256"])
    except Exception as exc:  # pragma: no cover - defensive auth fallback
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="invalid access token",
        ) from exc

    return int(payload["sub"])


def get_current_user_id(authorization: str | None = Header(default=None)) -> int:
    if not authorization or not authorization.startswith("Bearer "):
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="missing bearer token",
        )

    token = authorization.removeprefix("Bearer ").strip()
    return decode_access_token(token)

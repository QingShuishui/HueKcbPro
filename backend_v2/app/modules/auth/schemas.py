from pydantic import BaseModel


class LoginRequest(BaseModel):
    school_code: str
    academic_username: str
    password: str
    device_name: str
    platform: str | None = None
    app_version: str | None = None
    app_build: str | None = None


class RefreshRequest(BaseModel):
    refresh_token: str
    device_name: str | None = None
    platform: str | None = None
    app_version: str | None = None
    app_build: str | None = None

from pydantic import BaseModel


class LoginRequest(BaseModel):
    school_code: str
    academic_username: str
    password: str
    device_name: str


class RefreshRequest(BaseModel):
    refresh_token: str

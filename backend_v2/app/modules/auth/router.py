from fastapi import APIRouter, status
from fastapi.responses import JSONResponse

from app.modules.auth import service
from app.modules.auth.schemas import LoginRequest, RefreshRequest


router = APIRouter(prefix="/api/v1/auth", tags=["auth"])


@router.post("/login")
def login(payload: LoginRequest) -> dict:
    return service.login_with_academic_credentials(payload)


@router.post("/refresh")
def refresh(payload: RefreshRequest) -> dict:
    try:
        return service.refresh_session(payload)
    except ValueError:
        return JSONResponse(
            status_code=status.HTTP_401_UNAUTHORIZED,
            content={
                "code": "INVALID_REFRESH_TOKEN",
                "message": "登录已过期，请重新登录",
                "details": {},
            },
        )

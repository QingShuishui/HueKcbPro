from fastapi import Request
from fastapi.responses import JSONResponse

from app.modules.connectors.errors import InvalidCredentialsError


async def invalid_credentials_exception_handler(
    request: Request,
    exc: InvalidCredentialsError,
) -> JSONResponse:
    return JSONResponse(
        status_code=400,
        content={
            "code": "INVALID_CREDENTIALS",
            "message": "账号或密码错误",
            "request_id": getattr(request.state, "request_id", None),
            "details": {},
        },
    )


async def unhandled_exception_handler(
    request: Request,
    exc: Exception,
) -> JSONResponse:
    return JSONResponse(
        status_code=500,
        content={
            "code": "INTERNAL_ERROR",
            "message": "Unexpected server error.",
            "request_id": getattr(request.state, "request_id", None),
            "details": {},
        },
    )

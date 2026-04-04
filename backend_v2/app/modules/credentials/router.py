from fastapi import APIRouter, Depends
from pydantic import BaseModel

from app.core.security import get_current_user_id
from app.modules.credentials import service


router = APIRouter(prefix="/api/v1/jw", tags=["academic-binding"])


class BindRequest(BaseModel):
    school_code: str
    academic_username: str
    password: str


@router.post("/bind")
def bind(
    payload: BindRequest,
    user_id: int = Depends(get_current_user_id),
) -> dict:
    return service.bind_user_academic_credentials(
        user_id=user_id,
        school_code=payload.school_code,
        academic_username=payload.academic_username,
        password=payload.password,
        rebound=False,
    )


@router.post("/rebind")
def rebind(
    payload: BindRequest,
    user_id: int = Depends(get_current_user_id),
) -> dict:
    return service.bind_user_academic_credentials(
        user_id=user_id,
        school_code=payload.school_code,
        academic_username=payload.academic_username,
        password=payload.password,
        rebound=True,
    )

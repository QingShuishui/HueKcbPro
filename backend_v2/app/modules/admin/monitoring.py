from datetime import datetime, timedelta, timezone

from fastapi import APIRouter, Header, HTTPException, Query, status
from sqlalchemy import func

from app.core.db import SessionLocal
from app.core.settings import get_settings
from app.models.academic_binding import AcademicBinding
from app.models.request_log import RequestLog
from app.models.user import User
from app.models.user_client_info import UserClientInfo


router = APIRouter(prefix="/api/v1/admin/monitor", tags=["admin-monitor"])


def require_admin_token(x_admin_token: str | None = Header(default=None)) -> None:
    token = get_settings().admin_token
    if not token or x_admin_token != token:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="invalid admin token",
        )


def utc_now_iso() -> str:
    return datetime.now(timezone.utc).isoformat()


def record_client_info(
    *,
    user_id: int,
    device_name: str | None,
    platform: str | None,
    app_version: str | None,
    app_build: str | None,
) -> None:
    with SessionLocal() as db:
        info = db.query(UserClientInfo).filter_by(user_id=user_id).one_or_none()
        if info is None:
            info = UserClientInfo(
                user_id=user_id,
                device_name=device_name,
                platform=platform,
                app_version=app_version,
                app_build=app_build,
                last_seen_at=utc_now_iso(),
            )
            db.add(info)
        else:
            info.device_name = device_name
            info.platform = platform
            info.app_version = app_version
            info.app_build = app_build
            info.last_seen_at = utc_now_iso()
        db.commit()


def academic_username_for_user(user_id: int) -> str | None:
    with SessionLocal() as db:
        binding = db.query(AcademicBinding).filter_by(user_id=user_id).one_or_none()
        return binding.academic_username if binding else None


def record_schedule_log(
    *,
    user_id: int | None,
    action: str,
    status: str,
    duration_ms: int,
    error_message: str | None = None,
    academic_username: str | None = None,
) -> None:
    if academic_username is None and user_id is not None:
        academic_username = academic_username_for_user(user_id)
    with SessionLocal() as db:
        db.add(
            RequestLog(
                user_id=user_id,
                academic_username=academic_username,
                action=action,
                status=status,
                duration_ms=max(duration_ms, 0),
                error_message=error_message,
                created_at=utc_now_iso(),
            )
        )
        db.commit()


def _parse_iso(value: str | None) -> datetime | None:
    if not value:
        return None
    try:
        return datetime.fromisoformat(value)
    except ValueError:
        return None


def _recent_user_count(db, *, since: datetime) -> int:
    count = 0
    for value in db.query(User.last_login_at).filter(User.last_login_at.is_not(None)):
        last_login = _parse_iso(value[0])
        if last_login and last_login >= since:
            count += 1
    return count


@router.get("/summary")
def monitor_summary(x_admin_token: str | None = Header(default=None)) -> dict:
    require_admin_token(x_admin_token)
    now = datetime.now(timezone.utc)
    with SessionLocal() as db:
        total_users = db.query(User).count()
        bindings = db.query(AcademicBinding).count()
        current_logs = db.query(RequestLog).filter_by(action="current")
        refresh_logs = db.query(RequestLog).filter_by(action="refresh")
        all_schedule_logs = db.query(RequestLog)
        avg_duration = all_schedule_logs.with_entities(
            func.avg(RequestLog.duration_ms)
        ).scalar()
        max_duration = all_schedule_logs.with_entities(
            func.max(RequestLog.duration_ms)
        ).scalar()

        return {
            "users": {
                "total": total_users,
                "bound": bindings,
                "active_24h": _recent_user_count(db, since=now - timedelta(days=1)),
                "active_7d": _recent_user_count(db, since=now - timedelta(days=7)),
            },
            "schedule": {
                "current_count": current_logs.count(),
                "refresh_count": refresh_logs.count(),
                "success_count": all_schedule_logs.filter_by(status="success").count(),
                "error_count": all_schedule_logs.filter_by(status="error").count(),
                "queued_count": all_schedule_logs.filter_by(status="queued").count(),
                "average_duration_ms": int(avg_duration or 0),
                "max_duration_ms": int(max_duration or 0),
            },
        }


@router.get("/users")
def monitor_users(x_admin_token: str | None = Header(default=None)) -> dict:
    require_admin_token(x_admin_token)
    with SessionLocal() as db:
        rows = (
            db.query(User, AcademicBinding, UserClientInfo)
            .join(AcademicBinding, AcademicBinding.user_id == User.id)
            .outerjoin(UserClientInfo, UserClientInfo.user_id == User.id)
            .order_by(User.id.desc())
            .all()
        )
        return {
            "users": [
                {
                    "user_id": user.id,
                    "academic_username": binding.academic_username,
                    "school_code": binding.school_code,
                    "last_login_at": user.last_login_at,
                    "device_name": info.device_name if info else None,
                    "platform": info.platform if info else None,
                    "app_version": info.app_version if info else None,
                    "app_build": info.app_build if info else None,
                    "last_seen_at": info.last_seen_at if info else None,
                }
                for user, binding, info in rows
            ]
        }


@router.get("/schedule-logs")
def monitor_schedule_logs(
    x_admin_token: str | None = Header(default=None),
    limit: int = Query(default=100, ge=1, le=500),
) -> dict:
    require_admin_token(x_admin_token)
    with SessionLocal() as db:
        logs = (
            db.query(RequestLog)
            .order_by(RequestLog.id.desc())
            .limit(limit)
            .all()
        )
        return {
            "logs": [
                {
                    "id": log.id,
                    "created_at": log.created_at,
                    "user_id": log.user_id,
                    "academic_username": log.academic_username,
                    "action": log.action,
                    "status": log.status,
                    "duration_ms": log.duration_ms,
                    "error_message": log.error_message,
                }
                for log in logs
            ]
        }

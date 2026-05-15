from datetime import datetime, timedelta, timezone

from app.core.db import SessionLocal
from app.core.security import create_access_token, issue_refresh_token
from app.models.academic_binding import AcademicBinding
from app.models.refresh_token import RefreshToken
from app.models.user import User
from app.modules.admin.monitoring import record_client_info
from app.modules.connectors.hue_connector import HUEConnector
from app.modules.credentials.service import persist_binding_schedule


def _upsert_binding_and_schedule(payload, db) -> tuple[User, AcademicBinding]:
    binding = (
        db.query(AcademicBinding)
        .filter_by(
            school_code=payload.school_code,
            academic_username=payload.academic_username,
        )
        .one_or_none()
    )
    if binding is None:
        user = User(
            display_name=payload.academic_username,
            last_login_at=datetime.now(timezone.utc).isoformat(),
        )
        db.add(user)
        db.flush()
        binding = AcademicBinding(
            user_id=user.id,
            school_code=payload.school_code,
            academic_username=payload.academic_username,
            connector_key="hue",
            credential_status="valid",
        )
        db.add(binding)
        db.flush()
    else:
        user = binding.user
        user.last_login_at = datetime.now(timezone.utc).isoformat()
        binding.credential_status = "valid"

    connector_result = HUEConnector().fetch_schedule(
        payload.academic_username,
        payload.password,
    )
    persist_binding_schedule(db, binding, payload.password, connector_result)

    return user, binding


def login_with_academic_credentials(payload) -> dict:
    with SessionLocal() as db:
        user, binding = _upsert_binding_and_schedule(payload, db)
        user_id = user.id
        school_code = binding.school_code
        academic_username = binding.academic_username
        refresh_token = issue_refresh_token()
        db.add(
            RefreshToken(
                user_id=user_id,
                token_id=refresh_token,
                device_name=payload.device_name,
                expires_at=(
                    datetime.now(timezone.utc) + timedelta(days=30)
                ).isoformat(),
                revoked_at=None,
            )
        )
        db.commit()
        record_client_info(
            user_id=user_id,
            device_name=payload.device_name,
            platform=payload.platform,
            app_version=payload.app_version,
            app_build=payload.app_build,
        )

        return {
            "access_token": create_access_token(user_id),
            "refresh_token": refresh_token,
            "token_type": "bearer",
            "user": {
                "id": user_id,
                "school_code": school_code,
                "academic_username": academic_username,
            },
        }


def refresh_session(payload) -> dict:
    with SessionLocal() as db:
        token_record = (
            db.query(RefreshToken)
            .filter_by(token_id=payload.refresh_token, revoked_at=None)
            .one_or_none()
        )
        if token_record is None:
            raise ValueError("invalid refresh token")

        user_id = token_record.user_id
        device_name = token_record.device_name
        token_record.revoked_at = datetime.now(timezone.utc).isoformat()
        new_refresh_token = issue_refresh_token()
        db.add(
            RefreshToken(
                user_id=user_id,
                token_id=new_refresh_token,
                device_name=device_name,
                expires_at=(
                    datetime.now(timezone.utc) + timedelta(days=30)
                ).isoformat(),
                revoked_at=None,
            )
        )
        db.commit()
        if payload.app_version or payload.app_build or payload.platform:
            record_client_info(
                user_id=user_id,
                device_name=payload.device_name or device_name,
                platform=payload.platform,
                app_version=payload.app_version,
                app_build=payload.app_build,
            )

        return {
            "access_token": create_access_token(user_id),
            "refresh_token": new_refresh_token,
            "token_type": "bearer",
        }

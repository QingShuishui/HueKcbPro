import json
from datetime import datetime, timedelta, timezone

from fastapi import HTTPException, status

from app.core.db import SessionLocal
from app.core.security import decrypt_password, encrypt_password
from app.models.academic_binding import AcademicBinding
from app.models.encrypted_credential import EncryptedCredential
from app.models.schedule_snapshot import ScheduleSnapshot
from app.models.schedule_sync_state import ScheduleSyncState
from app.models.user import User
from app.modules.connectors.hue_connector import HUEConnector
from app.modules.schedule.cache import set_cached_schedule
from app.modules.schedule.service import normalize_connector_schedule


def encrypt_academic_password(password: str) -> str:
    return encrypt_password(password)


def persist_binding_schedule(db, binding: AcademicBinding, password: str, connector_result):
    normalized_schedule = normalize_connector_schedule(connector_result)
    encrypted_password = encrypt_academic_password(password)

    if binding.credential is None:
        db.add(
            EncryptedCredential(
                binding_id=binding.id,
                encrypted_password=encrypted_password,
            )
        )
    else:
        binding.credential.encrypted_password = encrypted_password

    sync_state = binding.sync_state
    if sync_state is None:
        sync_state = ScheduleSyncState(binding_id=binding.id)
        db.add(sync_state)
        db.flush()

    next_version = (sync_state.schedule_version or 0) + 1
    snapshot = ScheduleSnapshot(
        binding_id=binding.id,
        version=next_version,
        schedule_hash=normalized_schedule["schedule_hash"],
        semester_label=normalized_schedule["semester_label"],
        payload_json=json.dumps(normalized_schedule, ensure_ascii=False),
        generated_at=normalized_schedule["generated_at"],
    )
    db.add(snapshot)
    db.flush()

    sync_state.current_snapshot_id = snapshot.id
    sync_state.sync_status = "synced"
    sync_state.last_synced_at = normalized_schedule["generated_at"]
    sync_state.cache_expires_at = (
        datetime.now(timezone.utc) + timedelta(minutes=15)
    ).isoformat()
    sync_state.last_sync_error = None
    sync_state.schedule_hash = normalized_schedule["schedule_hash"]
    sync_state.schedule_version = next_version
    binding.credential_status = "valid"
    set_cached_schedule(
        binding.user_id,
        {
            "semester_label": normalized_schedule["semester_label"],
            "generated_at": normalized_schedule["generated_at"],
            "is_stale": False,
            "last_synced_at": sync_state.last_synced_at,
            "cache_expires_at": sync_state.cache_expires_at,
            "courses": normalized_schedule["courses"],
        },
    )


def bind_user_academic_credentials(
    *,
    user_id: int,
    school_code: str,
    academic_username: str,
    password: str,
    rebound: bool = False,
) -> dict:
    with SessionLocal() as db:
        user = db.get(User, user_id)
        if user is None:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="user not found",
            )

        binding = (
            db.query(AcademicBinding)
            .filter_by(user_id=user_id, school_code=school_code)
            .one_or_none()
        )
        if binding is None:
            binding = AcademicBinding(
                user_id=user_id,
                school_code=school_code,
                academic_username=academic_username,
                connector_key="hue",
                credential_status="valid",
            )
            db.add(binding)
            db.flush()
        else:
            binding.academic_username = academic_username
            binding.connector_key = "hue"

        connector_result = HUEConnector().fetch_schedule(academic_username, password)
        persist_binding_schedule(db, binding, password, connector_result)
        db.commit()

        return {
            "status": "rebound" if rebound else "bound",
            "school_code": school_code,
            "academic_username": academic_username,
        }


def refresh_binding_schedule(binding_id: int) -> None:
    with SessionLocal() as db:
        binding = db.get(AcademicBinding, binding_id)
        if binding is None or binding.credential is None:
            return

        password = decrypt_password(binding.credential.encrypted_password)
        connector_result = HUEConnector().fetch_schedule(
            binding.academic_username,
            password,
        )
        persist_binding_schedule(db, binding, password, connector_result)
        db.commit()

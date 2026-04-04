from app.core.db import SessionLocal
from app.core.security import decrypt_password
from app.models.academic_binding import AcademicBinding
from app.modules.connectors.hue_connector import HUEConnector
from app.modules.credentials.service import persist_binding_schedule
from app.modules.tasks.celery_app import celery_app


def retry_delay_seconds(retry_index: int) -> int:
    return [300, 900, 1800][min(retry_index, 2)]


@celery_app.task(autoretry_for=(Exception,), retry_backoff=False, max_retries=3)
def sync_schedule(binding_id: int) -> None:
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

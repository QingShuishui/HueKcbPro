from alembic import context
from sqlalchemy import engine_from_config, pool

from app.core.settings import get_settings
from app.models.base import Base
from app.models.user import User
from app.models.academic_binding import AcademicBinding
from app.models.encrypted_credential import EncryptedCredential
from app.models.schedule_snapshot import ScheduleSnapshot
from app.models.schedule_sync_state import ScheduleSyncState
from app.models.refresh_token import RefreshToken
from app.models.android_release import AndroidRelease


config = context.config
settings = get_settings()
config.set_main_option("sqlalchemy.url", settings.database_url)
target_metadata = Base.metadata


def run_migrations_online() -> None:
    connectable = engine_from_config(
        config.get_section(config.config_ini_section),
        prefix="sqlalchemy.",
        poolclass=pool.NullPool,
    )
    with connectable.connect() as connection:
        context.configure(connection=connection, target_metadata=target_metadata)
        with context.begin_transaction():
            context.run_migrations()

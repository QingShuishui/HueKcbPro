from sqlalchemy import create_engine, inspect

from app.models.base import Base
from app.models.user import User
from app.models.academic_binding import AcademicBinding
from app.models.schedule_snapshot import ScheduleSnapshot


def test_tables_can_be_created_in_metadata():
    engine = create_engine("sqlite:///:memory:")

    Base.metadata.create_all(engine)
    tables = set(inspect(engine).get_table_names())

    assert "users" in tables
    assert "academic_bindings" in tables
    assert "schedule_snapshots" in tables


def test_user_to_binding_relationship_is_declared():
    assert User.academic_bindings.property.mapper.class_ is AcademicBinding

from app.modules.tasks.celery_app import celery_app


def test_sync_schedule_task_is_registered():
    assert "app.modules.tasks.schedule_tasks.sync_schedule" in celery_app.tasks

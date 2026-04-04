from app.modules.tasks.schedule_tasks import retry_delay_seconds


def test_retry_backoff_grows_predictably():
    assert retry_delay_seconds(0) == 300
    assert retry_delay_seconds(1) == 900
    assert retry_delay_seconds(2) == 1800

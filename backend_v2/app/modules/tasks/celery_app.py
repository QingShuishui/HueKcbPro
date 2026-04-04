try:
    from celery import Celery
except ImportError:  # pragma: no cover - local fallback when Celery is unavailable
    class _TaskWrapper:
        def __init__(self, func):
            self._func = func

        def __call__(self, *args, **kwargs):
            return self._func(*args, **kwargs)

        def delay(self, *args, **kwargs):
            return self._func(*args, **kwargs)

    class Celery:  # type: ignore[override]
        def __init__(self, *args, **kwargs):
            self.conf = type("Conf", (), {})()

        def task(self, *args, **kwargs):
            def decorator(func):
                return _TaskWrapper(func)

            return decorator

from app.core.settings import get_settings


settings = get_settings()
celery_app = Celery(
    "kcb-backend-v2",
    broker=settings.redis_url,
    backend=settings.redis_url,
)
celery_app.conf.task_default_queue = "schedule"
celery_app.conf.imports = ("app.modules.tasks.schedule_tasks",)
if settings.app_env == "test":
    celery_app.conf.task_always_eager = True
    celery_app.conf.task_store_eager_result = False
    celery_app.conf.task_ignore_result = True

from app.modules.tasks import schedule_tasks  # noqa: E402,F401

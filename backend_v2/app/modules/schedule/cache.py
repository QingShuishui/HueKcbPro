import json

try:
    from redis import Redis
except ImportError:  # pragma: no cover - local fallback when redis is unavailable
    Redis = None

from app.core.settings import get_settings


_memory_cache: dict[str, str] = {}
redis_client = (
    Redis.from_url(get_settings().redis_url, decode_responses=True)
    if Redis is not None
    else None
)


def schedule_key(user_id: int) -> str:
    return f"schedule:{user_id}:current"


def get_cached_schedule(user_id: int) -> dict | None:
    if redis_client is not None:
        try:
            raw = redis_client.get(schedule_key(user_id))
        except Exception:  # pragma: no cover - network fallback
            raw = _memory_cache.get(schedule_key(user_id))
    else:
        raw = _memory_cache.get(schedule_key(user_id))
    return json.loads(raw) if raw else None


def set_cached_schedule(user_id: int, payload: dict) -> None:
    raw = json.dumps(payload, ensure_ascii=False)
    if redis_client is not None:
        try:
            redis_client.set(schedule_key(user_id), raw)
            return
        except Exception:  # pragma: no cover - network fallback
            pass
    _memory_cache[schedule_key(user_id)] = raw


def delete_cached_schedule(user_id: int) -> None:
    if redis_client is not None:
        try:
            redis_client.delete(schedule_key(user_id))
        except Exception:  # pragma: no cover - network fallback
            pass
    _memory_cache.pop(schedule_key(user_id), None)

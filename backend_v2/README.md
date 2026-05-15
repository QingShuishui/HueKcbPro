# backend_v2

Dockerized FastAPI backend for the HueKcbPro project.

## Local Start

```bash
docker compose up --build
```

This stack includes:

- `postgres` as the primary database
- `redis` as cache and Celery broker
- `migrate` to run `alembic upgrade head`
- `api` for FastAPI
- `worker` for Celery jobs
- `beat` for periodic task scheduling

## Migration

```bash
alembic upgrade head
```

## Verify

```bash
curl http://127.0.0.1:2581/health/live
curl http://127.0.0.1:2581/health/ready
curl http://127.0.0.1:2581/api/v1/app/update/android
```

The `/health/ready` response should include both `database` and `redis` fields.

Admin monitoring endpoints require `X-Admin-Token` matching `ADMIN_TOKEN`:

```bash
curl -H "X-Admin-Token: $ADMIN_TOKEN" http://127.0.0.1:2581/api/v1/admin/monitor/summary
curl -H "X-Admin-Token: $ADMIN_TOKEN" http://127.0.0.1:2581/api/v1/admin/monitor/users
curl -H "X-Admin-Token: $ADMIN_TOKEN" http://127.0.0.1:2581/api/v1/admin/monitor/schedule-logs
```

## Release Deploy

For pull-and-run deployment using published images, see:

[`DEPLOY.md`](./DEPLOY.md)

Release deployment uses:

- `docker-compose.release.yml`
- `.env.release`
- one reusable application image for `migrate/api/worker/beat`
- GitHub Release based publishing via `.github/workflows/backend-v2-docker.yml`
- internal-only `postgres` and `redis` by default

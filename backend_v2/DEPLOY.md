# Release Deployment

This backend is designed to be deployed from a single application image reused by:

- `migrate`
- `api`
- `worker`
- `beat`

`Postgres` and `Redis` use official upstream images.

## 1. Publish the application image

### Option A: GitHub Release publish

This repository includes a workflow at:

- `.github/workflows/backend-v2-docker.yml`

It publishes the image to:

- `ghcr.io/qingshuishui/kcb-backend-v2`

Recommended release flow:

1. Push your branch to GitHub
2. Create a tag like `backend-v0.1.1`
3. Create a GitHub Release from that tag and publish it

For server deployments, pin `APP_TAG` to the exact release tag you published, for example:

- `backend-v0.1.1`

Use `latest` only if you intentionally want to track the default branch image.

The workflow will build and push a multi-arch image for:

- `linux/amd64`
- `linux/arm64`

### Option B: Manual build and push

Build and push from the `backend_v2` directory:

```bash
docker build -t ghcr.io/qingshuishui/kcb-backend-v2:latest .
docker push ghcr.io/qingshuishui/kcb-backend-v2:latest
```

You can replace `latest` with a release tag such as `backend-v0.1.1`.

## 2. Prepare server files

On the target server, keep these files together:

- `docker-compose.release.yml`
- `.env.release`

Create `.env.release` from `.env.release.example`:

```bash
cp .env.release.example .env.release
```

Required edits:

- `APP_IMAGE`
- `APP_TAG`
- `POSTGRES_PASSWORD`
- `DATABASE_URL`
- `JWT_SECRET`
- `CREDENTIAL_ENCRYPTION_KEY`

For the default compose layout, `DATABASE_URL` should point to the `postgres` service host:

```env
DATABASE_URL=postgresql+psycopg://postgres:your-password@postgres:5432/kcb
```

Recommended release defaults:

```env
APP_IMAGE=ghcr.io/qingshuishui/kcb-backend-v2
APP_TAG=backend-v0.1.1
```

## 3. Start the full stack

```bash
docker compose --env-file .env.release -f docker-compose.release.yml up -d
```

This starts:

- PostgreSQL
- Redis
- Alembic migration job
- FastAPI API
- Celery worker
- Celery beat

Only the API service is exposed to the host by default. `postgres` and `redis` stay on the internal Docker network unless you explicitly add host port mappings.

## 4. Verify

```bash
curl http://127.0.0.1:8000/health/live
curl http://127.0.0.1:8000/health/ready
```

Expected:

- `/health/live` returns `{"status":"ok"}`
- `/health/ready` returns `status=ready`

## 5. Upgrade

Update the image tag in `.env.release`, then run:

```bash
docker compose --env-file .env.release -f docker-compose.release.yml pull
docker compose --env-file .env.release -f docker-compose.release.yml up -d
```

## Notes

- `migrate` is a one-shot container and should exit successfully.
- Persistent data is stored in named Docker volumes:
  - `postgres_data`
  - `redis_data`
- Put Nginx or Caddy in front of `api` if you want HTTPS and domain routing.
- If you use GHCR, make sure the package visibility is set appropriately for your deployment target.

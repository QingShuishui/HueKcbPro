# HueKcbPro

HueKcbPro is a school timetable project with a Flutter client and a Dockerized FastAPI backend.

## Structure

- `lib/`: Flutter app source
- `backend_v2/`: current FastAPI backend, Docker files, deployment docs
- `backend/`: earlier backend implementation kept in the repo

## Local Development

Flutter app:

```bash
flutter pub get
flutter run
```

Backend:

```bash
cd backend_v2
docker compose up --build
```

## Deployment

Production deployment for the current backend is documented in [`backend_v2/DEPLOY.md`](./backend_v2/DEPLOY.md).

The release image is published by GitHub Actions to:

```text
ghcr.io/qingshuishui/kcb-backend-v2
```

# HueKcbPro

HueKcbPro is a timetable system built for Hubei University of Education workflows, with a native Flutter client and a production-oriented FastAPI backend. The project focuses on fast schedule access, resilient cached data handling, and a delivery path that is practical for real Android releases and backend operations.

## Download

The Android app has already been built and published on GitHub Releases.

- [Download the latest release](https://github.com/QingShuishui/HueKcbPro/releases/latest)
- [Browse all releases](https://github.com/QingShuishui/HueKcbPro/releases)

## Why It Stands Out

- Native Flutter timetable experience instead of a thin web wrapper UI
- Real-time refresh for the latest timetable data, reducing stale information when classes are rescheduled
- Cached schedule fallback with warning states when network connectivity or backend cache freshness becomes a problem
- Session restore flow that can keep local access available when refresh fails offline
- Dockerized backend stack with API, database, cache, worker, and scheduler services
- Release-oriented delivery pipeline for Android builds and backend container publishing

## Tech Stack

### Mobile Client

- Flutter
- Dart
- Riverpod for state management
- Dio for HTTP networking
- Flutter Secure Storage for credentials and tokens
- Path Provider and Package Info Plus for local persistence and app metadata

### Backend

- FastAPI
- PostgreSQL
- Redis
- Celery workers and beat scheduler
- Docker and Docker Compose

### Delivery

- GitHub Actions
- GitHub Releases
- GitHub Container Registry
- Android release workflow

## Architecture

The repository currently contains a native mobile client and a Dockerized backend service:

- `lib/`: Flutter application source
- `test/`: Flutter widget and unit tests
- `backend_v2/`: current FastAPI backend, Docker setup, release deployment docs
- `backend/`: earlier backend implementation kept for reference
- `.github/workflows/`: Android release and backend container publishing workflows

At runtime, the Flutter client talks to the backend API for authentication, schedule retrieval, refresh requests, and update metadata. The current backend stack uses PostgreSQL for persistent data, Redis for cache and queue infrastructure, and Celery for background schedule-related work.

## Quick Start

### Flutter App

```bash
flutter pub get
flutter run
```

### Backend

```bash
cd backend_v2
docker compose up --build
```

## Deployment

Production deployment for the current backend is documented in [`backend_v2/DEPLOY.md`](./backend_v2/DEPLOY.md).

The backend release image is published through GitHub Actions to:

```text
ghcr.io/qingshuishui/kcb-backend-v2
```

## License

This project is licensed under the GNU General Public License v3.0.

If you distribute a modified version of this project, you must also provide the corresponding source code under GPL-3.0.

See [LICENSE](./LICENSE) for the full license text.

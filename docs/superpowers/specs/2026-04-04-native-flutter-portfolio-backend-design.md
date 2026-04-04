# Native Flutter Portfolio Backend Design

## Summary

This project will replace the current Flutter WebView shell with a native Flutter application backed by a new API-first Python backend. The product remains centered on real integration with the Hunan University of Engineering academic system, but the architecture will be rebuilt as a portfolio-quality project with clear module boundaries, caching, background jobs, middleware, observability, and failure handling.

Version 1 targets a single school integration, but the backend will define a connector abstraction so the academic-system integration layer can be extended later without reworking the rest of the system.

The recommended backend stack is:

- FastAPI for the HTTP API
- PostgreSQL for persistent business data
- Redis for cache and task broker
- SQLAlchemy 2 for ORM and data access
- Alembic for database migrations
- Celery for background refresh and retry jobs
- Sentry for exception monitoring
- Docker Compose for local development and portfolio-friendly deployment

## Goals

- Replace the current WebView experience with native Flutter screens and native state management.
- Keep real academic-system login and schedule synchronization as the core product value.
- Build a backend that looks complete and intentional as a portfolio project without becoming microservice-heavy.
- Support encrypted credential storage so the backend can refresh schedules in the background.
- Add Redis-backed schedule caching with automatic refresh behavior.
- Add middleware, structured error handling, health checks, and basic observability.
- Preserve Android OTA update support through a backend API.

## Non-Goals

- No multi-school marketplace in V1.
- No microservices, Kafka, Kubernetes, or service mesh.
- No web admin panel in V1 beyond minimal operational endpoints if needed later.
- No real-time push from the academic system because the upstream system does not provide a push channel.
- No iOS self-update installation flow.
- No attempt to fully eliminate CAPTCHA or guarantee perfect sync when the upstream system is unstable.

## Product Scope

### Frontend

- A native Flutter app replaces the current WebView shell.
- The app talks only to backend APIs rather than HTML pages.
- The app supports login, account binding, current schedule viewing, manual refresh, sync status display, and Android update checking.

### Backend

- The backend exposes a versioned REST API for mobile clients.
- The backend stores user accounts, encrypted academic-system credentials, schedule snapshots, sync state, and update metadata.
- The backend wraps school-specific scraping and parsing logic behind a connector interface.
- The backend uses asynchronous jobs to refresh schedules and warm caches.

## Recommended Architecture

### High-Level Shape

The backend should be implemented as a modular monolith:

- one deployable API service
- one PostgreSQL database
- one Redis instance
- one Celery worker service
- one Celery beat scheduler service

This keeps the system easy to explain and operate while still demonstrating production-minded engineering choices.

### Main Components

- Flutter native client
- FastAPI application
- PostgreSQL database
- Redis cache and broker
- Celery worker and beat
- HUE academic-system connector
- Sentry monitoring

### Why This Stack

- FastAPI fits an API-first mobile architecture well and keeps schemas and validation explicit.
- PostgreSQL makes the project feel like a real backend rather than a local demo server.
- Redis supports both schedule caching and async job orchestration without introducing extra infrastructure.
- Celery makes background refresh, retry, and cache warming concrete rather than theoretical.
- Sentry provides a real answer to crash and exception monitoring.

## Backend Module Boundaries

The backend should be split into focused modules with stable interfaces.

### `core`

Responsibilities:

- settings and environment loading
- database and Redis initialization
- JWT helpers
- encryption helpers
- logging setup
- Sentry setup

### `middleware`

Responsibilities:

- request ID propagation
- access logging
- error normalization
- CORS
- compression
- host and HTTPS safety controls

### `auth`

Responsibilities:

- app login
- access token issuance
- refresh token rotation
- device session management

### `users`

Responsibilities:

- application user profile
- school binding status
- account lifecycle helpers

### `connectors`

Responsibilities:

- define the academic-system connector interface
- implement `HUEConnector`
- isolate upstream login, CAPTCHA, fetch, and parsing logic

### `credentials`

Responsibilities:

- encrypted storage of academic-system username and password
- credential update and rotation
- invalid credential state tracking

### `schedule`

Responsibilities:

- normalized schedule models
- current schedule read API
- sync status API
- cache read and write rules
- schedule hash comparison
- current snapshot and history table management

### `tasks`

Responsibilities:

- background sync jobs
- retry and backoff behavior
- periodic cache warming
- weekly or time-window refresh scheduling

### `updates`

Responsibilities:

- Android update metadata endpoint
- APK upload metadata handling
- release notes and version checks

### `observability`

Responsibilities:

- health checks
- operational metrics hooks
- shared error codes and logging context

## Connector Design

Version 1 supports only the current Hunan University of Engineering academic system, but the code should not hard-code school behavior into unrelated modules.

The connector layer must expose this interface:

- `login()`
- `fetch_schedule()`
- `validate_credentials()`
- `map_error()`

The rest of the system should consume a normalized schedule result rather than raw HTML. This keeps future school expansion possible without rewriting auth, caching, tasks, or API handlers.

## Data Model

### Core Entities

The backend must model these entities in V1:

- `users`
- `academic_bindings`
- `encrypted_credentials`
- `schedule_snapshots`
- `schedule_sync_states`
- `refresh_tokens`
- `android_releases`

### Suggested Schedule-Related Fields

For each bound user, track:

- `last_synced_at`
- `cache_expires_at`
- `schedule_hash`
- `sync_status`
- `last_sync_error`
- `schedule_version`
- `credential_status`

### Schedule Snapshot Shape

The normalized schedule payload should be stored in a backend-owned format rather than copied from HTML. A snapshot should include:

- semester metadata
- generated timestamp
- normalized course list with explicit fields for course name, teacher, room, weekday, lesson start, lesson end, raw week expression, and parsed week numbers
- the computed hash used for change detection

## Credential Storage

The backend is allowed to store academic-system credentials because V1 needs automatic refresh and cache warming.

Requirements:

- credentials must be encrypted before persistence
- encryption keys must come from environment configuration, not source control
- plaintext credentials should never be written to logs
- invalid credentials should be tracked separately from transient sync failures

## Cache Strategy

### Recommendation

Use a `stale-while-revalidate` strategy for schedule reads.

### Read Behavior

1. The app requests the current schedule.
2. The backend checks Redis for the current schedule cache.
3. If the cache is fresh, return it immediately.
4. If the cache is stale but present, return the stale payload with freshness metadata and enqueue a background refresh.
5. If no cache exists, read the latest persisted snapshot from PostgreSQL.
6. If no persisted snapshot exists for `GET /api/v1/schedule/current`, enqueue a refresh job and return `202 Accepted` with a `SYNC_IN_PROGRESS` code.

### Refresh Triggers

The cache should be refreshed from four kinds of triggers:

- user-triggered refresh
- stale read access
- periodic scheduled warm-up jobs
- special time-window refreshes such as the start of a new week or term-sensitive periods

### Change Detection

The backend should not compare raw HTML to detect schedule changes. Instead:

- normalize the fetched schedule
- sort and serialize the meaningful schedule fields
- compute a stable SHA-256 hash
- compare the new hash with the current persisted hash
- update storage and cache only when the hash changes

## Sync Flow

### Initial Bind

1. User binds academic-system credentials from the app.
2. Backend validates the credentials through `HUEConnector`.
3. Backend encrypts and stores the credentials.
4. Backend performs an initial schedule sync.
5. Backend persists the schedule snapshot and writes Redis cache.
6. App receives the normalized native schedule payload.

### Normal Read Flow

1. App requests `GET /api/v1/schedule/current`.
2. Backend reads Redis.
3. If cache is fresh, return immediately.
4. If cache is stale, return cached data with `is_stale=true` and enqueue a refresh.
5. If cache is missing but PostgreSQL has a current snapshot, repopulate Redis from PostgreSQL, return that snapshot, and enqueue a refresh when `cache_expires_at` has passed.
6. If neither Redis nor PostgreSQL has a snapshot, return `202 Accepted` with `SYNC_IN_PROGRESS` and enqueue a refresh job.

### Background Refresh Flow

1. Celery worker pulls a sync job.
2. The worker loads encrypted credentials and decrypts them in memory.
3. `HUEConnector` logs into the academic system and fetches the latest schedule.
4. The worker normalizes the result and computes a new hash.
5. If the hash changed, the worker updates PostgreSQL and Redis.
6. If the hash did not change, the worker updates sync metadata only.

## Failure Handling

### Principle

Failures should degrade gracefully whenever possible. Upstream instability must not automatically translate into an empty schedule screen.

### Academic-System Failures

If the academic system is unavailable, slow, or returns unexpected content:

- do not delete the current cache
- do not delete the current persisted snapshot
- return the most recent successful schedule if available
- mark the response as stale or degraded
- record a structured sync error

### Credential Failures

If the connector can confidently determine that the user password is no longer valid:

- mark the academic binding as `credential_expired`
- stop aggressive automatic retries
- prompt the app to ask the user to rebind credentials

### Redis Failure

If Redis is unavailable:

- fall back to PostgreSQL reads
- skip cache writes until Redis recovers
- continue serving core schedule APIs if PostgreSQL is healthy

### PostgreSQL Failure

If PostgreSQL is unavailable:

- health readiness should fail
- write endpoints should fail explicitly
- the service should not pretend to be healthy

### Worker Failure

If a Celery worker crashes:

- API service stays available
- pending jobs are retried after worker recovery
- sync freshness may degrade, but the app can still read existing cache or snapshots

## Retry Strategy

Background sync jobs should be retried with bounded exponential backoff. Example behavior:

- first retry after 5 minutes
- second retry after 15 minutes
- third retry after 30 minutes

Retries should distinguish between:

- transient upstream failures
- CAPTCHA or parsing failures
- credential failures
- internal application failures

Credential failures should not use the same retry policy as transient network failures.

## Middleware Plan

The API should include the following middleware or equivalent request pipeline behavior:

- request ID middleware
- access logging middleware
- global exception normalization
- CORS middleware
- GZip response compression
- trusted host validation
- HTTPS redirect in deployed environments

Request IDs should appear in both logs and error responses so the mobile app and backend logs can be correlated.

## Error Contract

All API failures should return a consistent JSON shape. Example:

```json
{
  "code": "SYNC_DEGRADED",
  "message": "Schedule refresh failed. Returning the latest cached snapshot.",
  "request_id": "req_123",
  "details": {
    "is_stale": true,
    "last_synced_at": "2026-04-04T08:30:00Z"
  }
}
```

Expected high-level error codes include:

- `UNAUTHORIZED`
- `FORBIDDEN`
- `VALIDATION_ERROR`
- `CREDENTIAL_EXPIRED`
- `SYNC_IN_PROGRESS`
- `SYNC_DEGRADED`
- `UPSTREAM_UNAVAILABLE`
- `INTERNAL_ERROR`

## Health Checks And Crash Story

The project should expose:

- `GET /health/live`
- `GET /health/ready`

Portfolio-ready crash and recovery story:

- API process crashes are mitigated by process restarts and container restart policy.
- Worker crashes do not take down the main API.
- Redis outages degrade cache behavior but not necessarily schedule reads.
- Academic-system outages fall back to stale cache or stored snapshots.
- Exceptions and background job failures are captured by Sentry.

## API Surface

Version 1 should keep the API narrow and explicit.

Recommended endpoints:

- `POST /api/v1/auth/login`
- `POST /api/v1/auth/refresh`
- `POST /api/v1/jw/bind`
- `POST /api/v1/jw/rebind`
- `GET /api/v1/schedule/current`
- `POST /api/v1/schedule/refresh`
- `GET /api/v1/schedule/status`
- `GET /api/v1/app/update/android`
- `GET /health/live`
- `GET /health/ready`

## Frontend Implications

Replacing the WebView with native Flutter screens implies:

- the app owns login UI and validation
- the app renders schedules from structured JSON rather than DOM content
- the app can display freshness state such as `last_synced_at` and `is_stale`
- the app can show a credential-expired state distinctly from generic sync failure

The native app should preserve OTA update support through the new update endpoint.

## Testing Strategy

### Unit Tests

- semester and week calculations
- schedule normalization
- schedule hash generation
- cache freshness decisions
- error code mapping
- credential encryption helpers

### Connector Tests

- successful academic login
- invalid credential handling
- CAPTCHA failure handling
- parser contract tests against saved HTML fixtures

### API Tests

- login and token refresh
- academic binding and rebinding
- schedule reads with fresh cache
- schedule reads with stale cache
- standardized error response shape
- health checks

### Task Tests

- background refresh success path
- retry and backoff behavior
- stale cache fallback behavior
- no-op writes when schedule hash is unchanged

### Integration Tests

- API plus PostgreSQL plus Redis happy path
- Celery-driven refresh flow
- degraded read behavior when the connector fails

## Development And Deployment

The project should be easy to demo locally and easy to explain in a portfolio.

Recommended local stack via Docker Compose:

- API container
- PostgreSQL container
- Redis container
- Celery worker container
- Celery beat container

## File Layout

Suggested backend file layout:

- `backend_v2/app/main.py`
- `backend_v2/app/core/`
- `backend_v2/app/middleware/`
- `backend_v2/app/modules/auth/`
- `backend_v2/app/modules/users/`
- `backend_v2/app/modules/connectors/`
- `backend_v2/app/modules/credentials/`
- `backend_v2/app/modules/schedule/`
- `backend_v2/app/modules/tasks/`
- `backend_v2/app/modules/updates/`
- `backend_v2/app/modules/observability/`
- `backend_v2/alembic/`
- `backend_v2/tests/`

The implementation should use `backend_v2/` as the top-level directory for the new backend.

## Portfolio Positioning

This project should be explainable as:

- a native mobile client
- a Python API backend with real third-party system integration
- a modular connector architecture
- a cache-aware and failure-aware schedule synchronization service
- an engineering-focused project with middleware, retries, observability, and background tasks

## Open Constraints

- The upstream academic system may change HTML structure and break parsing.
- CAPTCHA quality may create unavoidable sync failures.
- True real-time update detection is not possible without upstream support.
- The first implementation should prefer clarity and stability over broad feature scope.

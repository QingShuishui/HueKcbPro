# App Polish And Runtime Completion Roadmap

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Turn the current native Flutter plus `backend_v2` prototype into a stable, polished, portfolio-ready app with session persistence, clearer auth UX, a good-looking timetable, and real runtime use of the intended backend stack.

**Architecture:** Keep the current modular monolith backend and native Flutter client, but shift focus from scaffolding to runtime correctness and polish. The next work should first stabilize auth/session and schedule rendering, then align the UI with the previous web visual style, and finally validate PostgreSQL, Redis, and Celery in real runtime instead of test-only or fallback paths.

**Tech Stack:** Flutter, Riverpod, Dio, Secure Storage, FastAPI, PostgreSQL, Redis, Celery, SQLAlchemy, Alembic, SQLite fallback for tests only

---

### Phase 0: Current Status Audit

- [ ] **Confirm what is already complete**
  - Native Flutter login page, schedule page, settings page exist
  - Backend auth, bind, schedule snapshot, cache fallback, and update endpoints exist
  - Parser now extracts real course cards instead of always returning an empty list

- [ ] **Record what is not yet complete**
  - No auto-login/session restore on app cold start
  - No polished Chinese error mapping for all auth and sync failures
  - Timetable UI is functional but not yet close to the previous web style
  - PostgreSQL and Redis are configured in code and Compose, but local runtime has mostly been validated with SQLite and in-memory fallback
  - Celery worker path exists, but real worker + Redis runtime has not been fully smoke-tested end to end

### Phase 1: Session Persistence And Auto-Login

**Goal:** The user should not need to manually log in after every app restart.

- [ ] Read tokens from secure storage during app startup
- [ ] Add an auth bootstrap state before routing to login or schedule
- [ ] Decide signed-in state from stored tokens
- [ ] Call `POST /api/v1/auth/refresh` on startup when refresh token exists
- [ ] Save rotated access/refresh tokens after bootstrap refresh
- [ ] If refresh fails, clear storage and return to login
- [ ] Add widget and controller tests for:
  - cold start with no tokens -> login page
  - cold start with valid tokens -> schedule page
  - cold start with invalid/expired tokens -> login page

**Files to expect:**
- `lib/main.dart`
- `lib/app.dart`
- `lib/features/auth/controllers/auth_controller.dart`
- `lib/features/auth/repositories/auth_repository.dart`
- `lib/core/storage/session_storage.dart`
- `test/app_boot_test.dart`
- `test/features/auth/auth_controller_test.dart`

### Phase 2: Auth Error UX

**Goal:** Users should see clear Chinese messages for wrong password, network failure, and server failure.

- [ ] Standardize backend auth errors to stable codes
  - `INVALID_CREDENTIALS`
  - `UPSTREAM_UNAVAILABLE`
  - `NETWORK_ERROR`
  - `INTERNAL_ERROR`

- [ ] Map backend error codes to user-facing Chinese messages in Flutter
- [ ] Keep backend messages in Chinese where the failure is already domain-specific
- [ ] Display inline login error state instead of a generic fallback
- [ ] Add a loading-disabled state to the login button

**Files to expect:**
- `backend_v2/app/middleware/error_handler.py`
- `backend_v2/app/modules/connectors/errors.py`
- `backend_v2/app/modules/auth/router.py`
- `lib/features/auth/repositories/auth_repository.dart`
- `lib/features/auth/controllers/auth_controller.dart`
- `lib/features/auth/pages/login_page.dart`
- `test/features/auth/login_page_test.dart`

### Phase 3: Make Schedule Screen Actually Useful

**Goal:** After login, the user should immediately see a usable timetable instead of a barely structured course list.

- [ ] Add a current week concept to the Flutter schedule screen
- [ ] Add week switching UI
- [ ] Add date strip for Monday to Sunday similar to the old web page
- [ ] Replace the current vertical card list with a timetable grid
- [ ] Render course blocks by weekday and lesson slot
- [ ] Show empty states for unused cells
- [ ] Show sync freshness:
  - last synced time
  - stale badge
  - failed refresh state
- [ ] Add pull-to-refresh
- [ ] Add a friendlier empty state when the backend returns zero courses

**Reference source to mimic:**
- `kcbPro/templates/timetable.html`
- `kcbPro/static/css/style.css`

**Files to expect:**
- `lib/features/schedule/models/course.dart`
- `lib/features/schedule/models/schedule.dart`
- `lib/features/schedule/controllers/schedule_controller.dart`
- `lib/features/schedule/pages/schedule_page.dart`
- `lib/features/schedule/widgets/schedule_grid.dart`
- new widgets for date strip, week picker, course cell, empty cell
- `test/features/schedule/schedule_page_test.dart`

### Phase 4: Visual Polish

**Goal:** The app should feel designed, not just technically functional.

- [ ] Reuse the old web app’s visual direction as reference:
  - soft paper background
  - rounded glass-like surfaces
  - pastel course colors
  - playful but restrained typography
  - friendly settings sheet

- [ ] Replace current seed-color default Material look
- [ ] Define explicit color tokens and spacing tokens
- [ ] Give schedule cells consistent height and readable typography
- [ ] Make the settings page visually coherent with the schedule page
- [ ] Add bottom navigation or a clearer home/settings switch if needed
- [ ] Verify layout on phone portrait first, then tablet width

**Files to expect:**
- `lib/app.dart`
- `lib/features/schedule/pages/schedule_page.dart`
- `lib/features/schedule/widgets/*`
- `lib/features/settings/pages/settings_page.dart`

### Phase 5: Settings Page Completion

**Goal:** Settings should only expose real functionality.

- [ ] Keep logout
- [ ] Remove dead controls permanently
- [ ] Add real “rebind credentials” flow only after backend and UI are both ready
- [ ] Show current academic username from auth state
- [ ] Add app version and backend base URL debug section in debug builds

**Files to expect:**
- `lib/features/settings/pages/settings_page.dart`
- `lib/features/auth/controllers/auth_controller.dart`
- `backend_v2/app/modules/credentials/router.py`

### Phase 6: Stack Completion Review

**Goal:** Be explicit about which intended technologies are truly in use.

#### PostgreSQL

Current state:
- configured in `backend_v2/.env`
- dependency present in `backend_v2/pyproject.toml`
- Compose service exists
- runtime code supports PostgreSQL
- tests currently use SQLite in-memory for speed and isolation

Completion tasks:
- [ ] Run backend against PostgreSQL locally
- [ ] Run Alembic migrations against PostgreSQL
- [ ] Verify login, bind, refresh, and schedule read with PostgreSQL

#### Redis

Current state:
- Redis dependency present
- cache abstraction exists
- Celery broker/backend points at Redis
- local code falls back to in-memory cache if Redis is unavailable

Completion tasks:
- [ ] Run backend with a real Redis instance
- [ ] Verify schedule cache writes and reads go through Redis
- [ ] Verify cache invalidation and stale behavior without fallback path

#### Celery

Current state:
- worker task scaffold exists
- retry delay logic exists
- refresh endpoint queues work
- full worker runtime has not been proven with real Redis in this workspace

Completion tasks:
- [ ] Start Redis + Celery worker + backend together
- [ ] Verify `/schedule/refresh` produces a real background refresh
- [ ] Verify stale cache becomes fresh after worker completes

### Phase 7: End-To-End Runtime Verification

**Goal:** Prove the app works beyond unit tests.

- [ ] Start backend with PostgreSQL and Redis
- [ ] Start Flutter app on emulator
- [ ] Verify wrong password -> Chinese error message
- [ ] Verify correct password -> schedule page with real timetable
- [ ] Kill app and reopen -> auto-login
- [ ] Pull to refresh -> request sent and UI updates
- [ ] Logout -> storage cleared and user returns to login

### Recommended Execution Order

1. Phase 1: Session persistence and auto-login
2. Phase 2: Auth error UX
3. Phase 3: Useful schedule screen
4. Phase 4: Visual polish
5. Phase 5: Settings page completion
6. Phase 6: Stack completion review for PostgreSQL, Redis, and Celery
7. Phase 7: End-to-end runtime verification

### Answer To The Stack Question

Current honest status:

- PostgreSQL: supported and configured, but not yet the primary runtime path used in the recent local verification runs
- Redis: partially used through the cache abstraction, but real Redis runtime has not been the main validated path yet
- Celery: scaffolded, tested at code level, not fully proven in a real multi-process local runtime

So the intended tech stack is **not yet fully exercised in real runtime**. The codebase is prepared for it, but the remaining work is to run and verify those services for real rather than depending on SQLite and in-memory fallback during development.

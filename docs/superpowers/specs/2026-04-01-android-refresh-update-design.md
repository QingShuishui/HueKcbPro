# Android Web Refresh And OTA Update Design

## Summary

This Flutter application remains a WebView shell around `https://kcb.mc91.cn` with token persistence. Two new capabilities will be added:

1. Refresh the current WebView page when the app returns to the foreground after more than one hour since the last successful page load or refresh.
2. Support Android in-app update checks by querying a simple Python backend for the latest APK metadata, downloading the APK, verifying its SHA-256 hash, and invoking the Android package installer.

iOS update handling remains out of scope for installation. The client may later add an App Store redirect path, but this implementation targets Android APK update flow only.

## Goals

- Keep course schedule content reasonably fresh without forcing frequent reloads while the app stays foregrounded.
- Allow the maintainer to upload a new Android APK to a simple backend and have the app detect and install it.
- Keep the design minimal and compatible with the existing small codebase.

## Non-Goals

- No delta updates, gray rollout, user cohorts, or release channels.
- No database-backed backend.
- No authenticated admin panel UI.
- No iOS self-update flow.

## Architecture

### Flutter Client

- Split the current single-file app into a small set of focused Dart files.
- Introduce a lifecycle-aware coordinator that observes `AppLifecycleState.resumed`.
- Persist two lightweight timestamps in secure storage:
  - the last saved token
  - the last successful WebView refresh time
- On resume, if more than one hour has elapsed since the last successful page load, silently refresh the current WebView.
- Independently on startup and resume, query the update endpoint for Android metadata.
- If a newer version exists, prompt the user to update. On confirmation, download the APK, verify SHA-256, and trigger installation.

### Python Backend

- Serve static APK files from a local `downloads/` directory.
- Expose one public JSON endpoint for Android update metadata.
- Expose one simple upload endpoint that accepts an APK file and release metadata, stores the file, computes SHA-256, and rewrites `latest-android.json`.
- Keep state on disk in JSON files.

## Data Model

### Client-side persisted keys

- `kcb_token`: current token extracted from `/t/<token>` URL
- `last_web_refresh_at`: ISO-8601 timestamp of the last successful page load or manual refresh trigger

### Backend metadata

`latest-android.json` structure:

```json
{
  "platform": "android",
  "version": "1.0.1",
  "build_number": 2,
  "force_update": false,
  "notes": "Bug fixes and refresh improvements",
  "apk_url": "http://<host>:<port>/downloads/kcb_pro_android-1.0.1+2.apk",
  "sha256": "<hex digest>",
  "published_at": "2026-04-01T10:00:00Z"
}
```

## Refresh Flow

1. App starts and loads either `/login` or `/t/<token>`.
2. When a page finishes loading, store the current timestamp as `last_web_refresh_at`.
3. When the app returns to foreground, read `last_web_refresh_at`.
4. If the timestamp is missing or less than one hour old, do nothing.
5. If it is older than one hour, call WebView `reload()` without changing the current URL.
6. When the reloaded page completes successfully, update `last_web_refresh_at`.

This is silent and preserves the active route as much as the website itself allows.

## Android Update Flow

1. Client reads its current app version and build number from package metadata.
2. Client requests `GET /api/update/android`.
3. If `build_number` is not greater than the local build number, stop.
4. If newer, show a dialog with version and release notes.
5. If user confirms, download the APK to app documents or cache storage.
6. Compute SHA-256 for the downloaded file and compare with backend metadata.
7. If valid, trigger Android installation using a platform plugin.
8. If invalid, delete the file and show an error.

## Error Handling

### Refresh

- Ignore refresh checks until WebView is initialized.
- If reload fails, keep the old timestamp unchanged so the app can retry on a later resume.
- Do not clear token just because refresh was attempted.

### Update

- If metadata request fails, skip update silently or log it.
- If download fails, show a user-visible error and allow retry later.
- If checksum verification fails, abort installation and remove the bad file.
- If installer invocation fails due to missing permission or platform restrictions, report that clearly to the user.

## Testing Strategy

- Add unit tests for refresh timing logic.
- Add unit tests for update comparison logic and metadata parsing.
- Add unit tests for checksum helper behavior where feasible.
- Remove the stale template counter widget test and replace it with tests that match the actual app behavior.

## File Layout

### Flutter

- `lib/main.dart`: app bootstrap
- `lib/app.dart`: app widget tree and high-level page wiring
- `lib/services/token_storage_service.dart`: token and timestamp persistence
- `lib/services/refresh_policy.dart`: pure time-based refresh decision logic
- `lib/services/update_service.dart`: update metadata fetch, version comparison, download, checksum verification, installation trigger
- `lib/models/update_info.dart`: update metadata model
- `lib/pages/app_webview_page.dart`: WebView lifecycle and UI
- `test/refresh_policy_test.dart`: refresh logic tests
- `test/update_info_test.dart`: update parsing and version comparison tests

### Python backend

- `backend/app.py`: HTTP API and file serving
- `backend/storage/latest-android.json`: generated latest metadata
- `backend/downloads/`: uploaded APK files
- `backend/README.md`: how to run and publish a release
- `backend/requirements.txt`: backend dependencies

## Open Constraints

- Android installation requires adding the right plugins and manifest/provider integration.
- The exact plugin choice should favor minimal setup and current Flutter compatibility.
- The backend will start without authentication to keep scope small; it should only be deployed in a controlled environment.

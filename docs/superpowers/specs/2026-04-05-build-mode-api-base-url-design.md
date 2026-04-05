# Build Mode API Base URL Design

## Goal

Make the Flutter client choose its backend base URL by build mode:

- `release` and `profile` builds default to `https://api-kcb.yan06.com/api/v1`
- `debug` builds continue using local development endpoints
- `--dart-define=API_BASE_URL=...` remains the highest-priority override

The same rule must apply to both the main API client and the Android update metadata endpoint.

## Current State

The app currently resolves its API base URL in `lib/core/network/api_base_url.dart` and already supports a compile-time override via `API_BASE_URL`.

However:

- the default path always points to local development hosts
- the Android update service uses its own hard-coded URL in `lib/services/update_service.dart`
- release builds and update checks can therefore target different environments unless every build is manually overridden

## Recommended Approach

Use one shared resolver for all backend URLs.

`ApiBaseUrl` will remain the single source of truth and expose:

- a resolved API base URL for `/api/v1`
- a derived Android update metadata URL for `/api/v1/app/update/android`

Resolution order:

1. Explicit override from `--dart-define=API_BASE_URL=...`
2. `release` or `profile` build defaults to `https://api-kcb.yan06.com/api/v1`
3. `debug` Android build defaults to `http://10.0.2.2:8000/api/v1`
4. `debug` non-Android build defaults to `http://127.0.0.1:8000/api/v1`

## Architecture

### API Base URL Resolver

`ApiBaseUrl` will own environment selection logic.

It should use build-mode information instead of relying only on platform checks. This keeps release builds deterministic and avoids requiring manual configuration for production.

The resolver should also normalize the returned value to the `/api/v1` base path so both repositories and service classes consume the same contract.

### Update Service

`UpdateService` should stop hard-coding `http://127.0.0.1:8000/api/v1/app/update/android`.

Instead, it should derive its default metadata URL from the shared resolver so update checks always follow the same environment as the rest of the app. This avoids a class of bugs where login and schedule APIs point to production while update checks still point to localhost.

## Data Flow

### Debug build

- No `API_BASE_URL` override
- Main API client uses local host base URL
- Android update metadata uses the same local base URL with `/app/update/android`

### Release/profile build

- No `API_BASE_URL` override
- Main API client uses `https://api-kcb.yan06.com/api/v1`
- Android update metadata uses `https://api-kcb.yan06.com/api/v1/app/update/android`

### Explicit override

- If `API_BASE_URL` is provided, both API client and update service use it regardless of build mode

## Error Handling

No new runtime error paths are required.

The change is configuration-focused. Existing networking and update error handling remains unchanged. The only requirement is that shared URL construction must not produce malformed URLs.

## Testing

Update unit tests to cover:

- debug Android default
- debug non-Android default
- release/profile default production URL
- explicit override precedence
- update service default metadata URL following the shared resolver

No integration or UI test changes are required for this scope.

## Files To Modify

- `lib/core/network/api_base_url.dart`
- `lib/services/update_service.dart`
- `test/core/network/api_base_url_test.dart`
- `test/services/update_service_test.dart`

## Out Of Scope

- Runtime environment switching from settings UI
- Separate staging environment support
- Changes to backend deployment or DNS

# Build Mode API Base URL Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make release/profile builds default to the deployed API host while debug builds keep local endpoints, with one shared resolver used by both the main API client and Android update checks.

**Architecture:** Keep `ApiBaseUrl` as the single source of truth for backend URL selection. Extend it to understand build mode and derive the Android update metadata URL from the resolved API base so all network entry points stay in sync.

**Tech Stack:** Flutter, Dart, Dio, flutter_test

---

### Task 1: Extend the shared API URL resolver

**Files:**
- Modify: `lib/core/network/api_base_url.dart`
- Test: `test/core/network/api_base_url_test.dart`

- [ ] **Step 1: Write the failing tests**

Update `test/core/network/api_base_url_test.dart` so it covers:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:kcb_pro_android/core/network/api_base_url.dart';

void main() {
  test('uses Android emulator loopback host by default in debug mode', () {
    expect(
      ApiBaseUrl.resolve(
        isAndroid: true,
        isReleaseMode: false,
        isProfileMode: false,
      ),
      'http://10.0.2.2:8000/api/v1',
    );
  });

  test('uses localhost by default on non-Android platforms in debug mode', () {
    expect(
      ApiBaseUrl.resolve(
        isAndroid: false,
        isReleaseMode: false,
        isProfileMode: false,
      ),
      'http://127.0.0.1:8000/api/v1',
    );
  });

  test('uses deployed API host by default in release mode', () {
    expect(
      ApiBaseUrl.resolve(
        isAndroid: true,
        isReleaseMode: true,
        isProfileMode: false,
      ),
      'https://api-kcb.yan06.com/api/v1',
    );
  });

  test('uses deployed API host by default in profile mode', () {
    expect(
      ApiBaseUrl.resolve(
        isAndroid: false,
        isReleaseMode: false,
        isProfileMode: true,
      ),
      'https://api-kcb.yan06.com/api/v1',
    );
  });

  test('prefers explicit dart-define override when provided', () {
    expect(
      ApiBaseUrl.resolve(
        override: 'http://192.168.1.8:8000/api/v1',
        isAndroid: true,
        isReleaseMode: true,
        isProfileMode: true,
      ),
      'http://192.168.1.8:8000/api/v1',
    );
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run:

```bash
flutter test test/core/network/api_base_url_test.dart
```

Expected: FAIL because `ApiBaseUrl.resolve` does not yet accept build-mode parameters and still defaults all builds to local URLs.

- [ ] **Step 3: Write minimal implementation**

Update `lib/core/network/api_base_url.dart` to:

```dart
import 'dart:io';

import 'package:flutter/foundation.dart';

class ApiBaseUrl {
  static const _override = String.fromEnvironment('API_BASE_URL');
  static const _production = 'https://api-kcb.yan06.com/api/v1';
  static const _androidDebug = 'http://10.0.2.2:8000/api/v1';
  static const _localDebug = 'http://127.0.0.1:8000/api/v1';

  static String resolve({
    String? override,
    bool? isAndroid,
    bool? isReleaseMode,
    bool? isProfileMode,
  }) {
    final explicit = (override ?? _override).trim();
    if (explicit.isNotEmpty) {
      return explicit;
    }

    final releaseMode = isReleaseMode ?? kReleaseMode;
    final profileMode = isProfileMode ?? kProfileMode;
    if (releaseMode || profileMode) {
      return _production;
    }

    final android = isAndroid ?? (!kIsWeb && Platform.isAndroid);
    return android ? _androidDebug : _localDebug;
  }

  static String resolveAndroidUpdateMetadataUrl({
    String? override,
    bool? isAndroid,
    bool? isReleaseMode,
    bool? isProfileMode,
  }) {
    return '${resolve(
      override: override,
      isAndroid: isAndroid,
      isReleaseMode: isReleaseMode,
      isProfileMode: isProfileMode,
    )}/app/update/android';
  }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run:

```bash
flutter test test/core/network/api_base_url_test.dart
```

Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add lib/core/network/api_base_url.dart test/core/network/api_base_url_test.dart
git commit -m "feat: switch api base url by build mode"
```

### Task 2: Make the update service use the shared resolver

**Files:**
- Modify: `lib/services/update_service.dart`
- Test: `test/services/update_service_test.dart`

- [ ] **Step 1: Write the failing test**

Update `test/services/update_service_test.dart` to assert the default update metadata URL comes from the shared resolver:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:kcb_pro_android/core/network/api_base_url.dart';
import 'package:kcb_pro_android/services/update_service.dart';

void main() {
  test('uses the shared backend resolver for Android update metadata', () {
    final service = UpdateService();

    expect(
      service.updateMetadataUrl,
      ApiBaseUrl.resolveAndroidUpdateMetadataUrl(),
    );
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run:

```bash
flutter test test/services/update_service_test.dart
```

Expected: FAIL because `UpdateService` still hard-codes the localhost update endpoint.

- [ ] **Step 3: Write minimal implementation**

Update `lib/services/update_service.dart` so the default URL is derived from `ApiBaseUrl`:

```dart
import '../core/network/api_base_url.dart';
import '../models/update_info.dart';

class UpdateService {
  UpdateService({
    HttpClient? httpClient,
    String? updateMetadataUrl,
  }) : updateMetadataUrl =
           updateMetadataUrl ?? ApiBaseUrl.resolveAndroidUpdateMetadataUrl(),
       _httpClient = httpClient ?? HttpClient();

  final HttpClient _httpClient;
  final String updateMetadataUrl;
```

Keep the rest of the service behavior unchanged.

- [ ] **Step 4: Run focused tests to verify they pass**

Run:

```bash
flutter test test/services/update_service_test.dart test/core/network/api_base_url_test.dart
```

Expected: PASS

- [ ] **Step 5: Run a broader regression slice**

Run:

```bash
flutter test test/features/auth/auth_repository_test.dart test/services/update_service_test.dart test/core/network/api_base_url_test.dart
```

Expected: PASS

- [ ] **Step 6: Commit**

```bash
git add lib/services/update_service.dart test/services/update_service_test.dart
git commit -m "feat: share api base url with update service"
```

### Task 3: Final verification

**Files:**
- Verify: `lib/core/network/api_base_url.dart`
- Verify: `lib/services/update_service.dart`
- Verify: `test/core/network/api_base_url_test.dart`
- Verify: `test/services/update_service_test.dart`

- [ ] **Step 1: Run the full targeted verification**

Run:

```bash
flutter test test/core/network/api_base_url_test.dart test/services/update_service_test.dart test/features/auth/auth_repository_test.dart
```

Expected: PASS with all selected tests green.

- [ ] **Step 2: Review the diff**

Run:

```bash
git diff -- lib/core/network/api_base_url.dart lib/services/update_service.dart test/core/network/api_base_url_test.dart test/services/update_service_test.dart docs/superpowers/specs/2026-04-05-build-mode-api-base-url-design.md docs/superpowers/plans/2026-04-05-build-mode-api-base-url.md
```

Expected: only the intended build-mode URL selection and update-service wiring changes are present.

- [ ] **Step 3: Push when ready**

Run:

```bash
git push origin main
```

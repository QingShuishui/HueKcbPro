# Android Refresh And OTA Update Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add one-hour-on-resume WebView refresh and Android APK update support backed by a minimal Python HTTP service.

**Architecture:** The Flutter app will split lifecycle, storage, and update logic into focused files. A small Python backend will persist release metadata as JSON and serve APK files directly from disk.

**Tech Stack:** Flutter, Dart, `webview_flutter`, `flutter_secure_storage`, Android package install plugin, Python, FastAPI or Flask-compatible minimal HTTP service.

---

### Task 1: Add failing tests for refresh timing logic

**Files:**
- Create: `test/refresh_policy_test.dart`
- Create: `lib/services/refresh_policy.dart`

- [ ] **Step 1: Write the failing test**

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:kcb_pro_android/services/refresh_policy.dart';

void main() {
  test('returns true when last refresh is older than one hour', () {
    final now = DateTime(2026, 4, 1, 12, 0, 0);
    final lastRefresh = now.subtract(const Duration(hours: 1, minutes: 1));

    expect(RefreshPolicy.shouldRefresh(now: now, lastRefreshAt: lastRefresh), isTrue);
  });

  test('returns false when last refresh is within one hour window', () {
    final now = DateTime(2026, 4, 1, 12, 0, 0);
    final lastRefresh = now.subtract(const Duration(minutes: 59));

    expect(RefreshPolicy.shouldRefresh(now: now, lastRefreshAt: lastRefresh), isFalse);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/refresh_policy_test.dart`
Expected: FAIL because `RefreshPolicy` does not exist yet.

- [ ] **Step 3: Write minimal implementation**

```dart
class RefreshPolicy {
  static const refreshInterval = Duration(hours: 1);

  static bool shouldRefresh({
    required DateTime now,
    required DateTime? lastRefreshAt,
  }) {
    if (lastRefreshAt == null) {
      return false;
    }

    return now.difference(lastRefreshAt) > refreshInterval;
  }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/refresh_policy_test.dart`
Expected: PASS

### Task 2: Add failing tests for update metadata parsing and comparison

**Files:**
- Create: `test/update_info_test.dart`
- Create: `lib/models/update_info.dart`

- [ ] **Step 1: Write the failing test**

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:kcb_pro_android/models/update_info.dart';

void main() {
  test('parses update metadata from json', () {
    final info = UpdateInfo.fromJson({
      'platform': 'android',
      'version': '1.0.1',
      'build_number': 2,
      'force_update': false,
      'notes': 'Bug fixes',
      'apk_url': 'http://localhost/downloads/app.apk',
      'sha256': 'abc',
      'published_at': '2026-04-01T10:00:00Z',
    });

    expect(info.buildNumber, 2);
    expect(info.apkUrl, 'http://localhost/downloads/app.apk');
  });

  test('detects newer build number correctly', () {
    final info = UpdateInfo(
      platform: 'android',
      version: '1.0.1',
      buildNumber: 2,
      forceUpdate: false,
      notes: 'Bug fixes',
      apkUrl: 'http://localhost/downloads/app.apk',
      sha256: 'abc',
      publishedAt: DateTime.parse('2026-04-01T10:00:00Z'),
    );

    expect(info.isNewerThan(localBuildNumber: 1), isTrue);
    expect(info.isNewerThan(localBuildNumber: 2), isFalse);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/update_info_test.dart`
Expected: FAIL because `UpdateInfo` does not exist yet.

- [ ] **Step 3: Write minimal implementation**

```dart
class UpdateInfo {
  UpdateInfo({
    required this.platform,
    required this.version,
    required this.buildNumber,
    required this.forceUpdate,
    required this.notes,
    required this.apkUrl,
    required this.sha256,
    required this.publishedAt,
  });

  final String platform;
  final String version;
  final int buildNumber;
  final bool forceUpdate;
  final String notes;
  final String apkUrl;
  final String sha256;
  final DateTime publishedAt;

  factory UpdateInfo.fromJson(Map<String, dynamic> json) {
    return UpdateInfo(
      platform: json['platform'] as String,
      version: json['version'] as String,
      buildNumber: json['build_number'] as int,
      forceUpdate: json['force_update'] as bool,
      notes: json['notes'] as String,
      apkUrl: json['apk_url'] as String,
      sha256: json['sha256'] as String,
      publishedAt: DateTime.parse(json['published_at'] as String),
    );
  }

  bool isNewerThan({required int localBuildNumber}) {
    return buildNumber > localBuildNumber;
  }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/update_info_test.dart`
Expected: PASS

### Task 3: Implement storage and lifecycle wiring for refresh

**Files:**
- Modify: `lib/main.dart`
- Create: `lib/app.dart`
- Create: `lib/pages/app_webview_page.dart`
- Create: `lib/services/token_storage_service.dart`
- Modify: `test/widget_test.dart`

- [ ] **Step 1: Write the failing test**

Add a focused widget or unit test that expects refresh decisions to stay outside the UI and removes the template counter assertions.

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test`
Expected: FAIL because current widget test still expects counter UI.

- [ ] **Step 3: Write minimal implementation**

Create focused files so the page state can:
- implement `WidgetsBindingObserver`
- save `last_web_refresh_at` on `onPageFinished`
- on `resumed`, call `RefreshPolicy.shouldRefresh`
- call `_controller.reload()` when true

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test`
Expected: PASS for refresh-related tests

### Task 4: Implement Android update service in Flutter

**Files:**
- Modify: `pubspec.yaml`
- Create: `lib/services/update_service.dart`
- Create: `lib/models/update_info.dart`
- Modify: `lib/pages/app_webview_page.dart`

- [ ] **Step 1: Write the failing test**

Add tests that instantiate `UpdateInfo` and compare build numbers, plus service helper tests for checksum utilities where possible.

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/update_info_test.dart`
Expected: FAIL until model and helpers exist.

- [ ] **Step 3: Write minimal implementation**

Add dependencies for:
- HTTP requests
- package info
- path provider
- crypto
- APK installation trigger

Implement update service methods for:
- fetching update JSON
- checking whether update is newer
- downloading APK
- validating SHA-256
- invoking installer

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test`
Expected: PASS

### Task 5: Implement Python backend

**Files:**
- Create: `backend/app.py`
- Create: `backend/requirements.txt`
- Create: `backend/storage/latest-android.json`
- Create: `backend/downloads/.gitkeep`
- Create: `backend/README.md`

- [ ] **Step 1: Write the failing test**

For this minimal backend, use a manual verification path instead of automated tests:
- start service
- request empty metadata
- upload APK
- request metadata again

- [ ] **Step 2: Run manual verification to observe missing routes**

Run: `python3 backend/app.py`
Expected: service startup or route absence until implementation exists.

- [ ] **Step 3: Write minimal implementation**

Implement:
- `GET /api/update/android`
- `POST /api/admin/upload`
- static file serving for `/downloads`
- on upload, save file and rewrite `latest-android.json`

- [ ] **Step 4: Run verification**

Run:
- `python3 backend/app.py`
- `curl http://127.0.0.1:8000/api/update/android`

Expected: JSON response from metadata endpoint.

### Task 6: Verify integrated flow

**Files:**
- Modify if needed: any of the above

- [ ] **Step 1: Run Flutter tests**

Run: `flutter test`
Expected: PASS

- [ ] **Step 2: Run analyzer**

Run: `flutter analyze`
Expected: no errors

- [ ] **Step 3: Start backend and smoke-test API**

Run: `python3 backend/app.py`
Expected: backend starts on local port

- [ ] **Step 4: Confirm Android integration constraints**

Document that full APK installation requires running on an Android device and cannot be fully proven in this shell environment.

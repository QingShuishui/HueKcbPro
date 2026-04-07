# Schedule Refresh Warning Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a separate warning action next to schedule refresh when cached schedule data is being shown because the device is offline or because the backend has marked the schedule cache as stale.

**Architecture:** Keep the schedule payload model unchanged and let `ScheduleController` own a derived warning enum. `SchedulePage` reads that warning state to render a separate tappable warning action with warning-specific `SnackBar` copy while preserving the existing refresh flow.

**Tech Stack:** Flutter, Material, Riverpod, flutter_test

---

### Task 1: Lock warning-state behavior with controller tests

**Files:**
- Modify: `test/features/schedule/schedule_controller_test.dart`
- Modify: `lib/features/schedule/controllers/schedule_controller.dart`

- [ ] **Step 1: Write the failing tests**

```dart
test('loadSchedule keeps cached stale schedule and exposes staleCache warning', () async {
  final container = ProviderContainer(
    overrides: [
      scheduleRepositoryProvider.overrideWithValue(_StaleCachedScheduleRepository()),
    ],
  );

  await container.read(scheduleControllerProvider.notifier).loadSchedule();

  final notifier = container.read(scheduleControllerProvider.notifier);
  expect(notifier.warningState, ScheduleRefreshWarning.staleCache);
});

test('manualRefresh marks offlineCache when refresh fails with cached schedule', () async {
  final container = ProviderContainer(
    overrides: [
      scheduleRepositoryProvider.overrideWithValue(_OfflineRefreshScheduleRepository()),
    ],
  );

  await container.read(scheduleControllerProvider.notifier).loadSchedule();
  await container.read(scheduleControllerProvider.notifier).manualRefresh();

  final notifier = container.read(scheduleControllerProvider.notifier);
  expect(notifier.warningState, ScheduleRefreshWarning.offlineCache);
});
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `flutter test test/features/schedule/schedule_controller_test.dart`
Expected: FAIL because `ScheduleController` does not expose a warning enum yet.

- [ ] **Step 3: Write minimal implementation**

```dart
enum ScheduleRefreshWarning { none, staleCache, offlineCache }

ScheduleRefreshWarning _warningState = ScheduleRefreshWarning.none;

ScheduleRefreshWarning get warningState => _warningState;
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `flutter test test/features/schedule/schedule_controller_test.dart`
Expected: PASS

### Task 2: Render the warning badge and message in the schedule page

**Files:**
- Modify: `test/features/schedule/schedule_page_test.dart`
- Modify: `lib/features/schedule/pages/schedule_page.dart`

- [ ] **Step 1: Write the failing tests**

```dart
testWidgets('shows stale cache warning action and snackbar copy', (tester) async {
  await tester.pumpWidget(...);

  await tester.tap(find.byKey(const ValueKey('schedule-warning-button')));
  await tester.pump();

  expect(find.text('当前显示的是缓存课表，可能不是最新数据'), findsOneWidget);
});

testWidgets('shows offline cache warning action and keeps refresh action tappable', (tester) async {
  await tester.pumpWidget(...);

  expect(find.byKey(const ValueKey('schedule-warning-button')), findsOneWidget);
  await tester.tap(find.byKey(const ValueKey('schedule-refresh-button')));
  await tester.pump();
  expect(find.textContaining('正在同步课表'), findsOneWidget);
});
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `flutter test test/features/schedule/schedule_page_test.dart`
Expected: FAIL because the refresh action does not render a warning badge or warning `SnackBar`.

- [ ] **Step 3: Write minimal implementation**

```dart
Stack(
  children: const [
    _ScheduleWarningButton(...),
    IconButton(...),
  ],
)
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `flutter test test/features/schedule/schedule_page_test.dart`
Expected: PASS

### Task 3: Verify the focused schedule suite

**Files:**
- Modify: `lib/features/schedule/controllers/schedule_controller.dart`
- Modify: `lib/features/schedule/pages/schedule_page.dart`
- Modify: `test/features/schedule/schedule_controller_test.dart`
- Modify: `test/features/schedule/schedule_page_test.dart`

- [ ] **Step 1: Run the focused suite**

Run: `flutter test test/features/schedule/schedule_controller_test.dart test/features/schedule/schedule_page_test.dart`
Expected: PASS

- [ ] **Step 2: Review for warning-state regressions**

```text
Confirm refresh success still clears the warning state unless the returned schedule stays stale.
Confirm full-page load failure without cache still shows the existing retry screen.
Confirm non-network refresh failure with a fresh cached schedule does not show a warning action.
```

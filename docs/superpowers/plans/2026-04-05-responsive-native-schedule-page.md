# Responsive Native Schedule Page Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Rebuild the native schedule page so the current-week view matches the previous web layout structure while fitting the full week on screen without horizontal scrolling.

**Architecture:** Keep the existing data loading and filtering logic in `SchedulePage`, but replace the horizontally scrolling date strip and fixed-width `Table` with responsive layout widgets driven by `LayoutBuilder`. Preserve the current native visual language while compressing spacing and typography based on available width.

**Tech Stack:** Flutter, Material, flutter_test, Riverpod

---

### Task 1: Lock in responsive layout expectations with widget tests

**Files:**
- Modify: `test/features/schedule/schedule_grid_test.dart`
- Modify: `test/features/schedule/schedule_page_test.dart`

- [ ] **Step 1: Write the failing tests**

```dart
testWidgets('renders schedule grid without horizontal scroll view', (tester) async {
  // Pump ScheduleGrid in a narrow mobile-sized viewport.
  // Assert weekday headers and course content remain visible.
  // Assert no horizontal SingleChildScrollView exists.
});

testWidgets('renders date strip as fixed seven-column layout', (tester) async {
  // Pump SchedulePage with schedule data.
  // Assert seven date tiles exist without a horizontal ListView.
});
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `flutter test test/features/schedule/schedule_grid_test.dart test/features/schedule/schedule_page_test.dart`
Expected: FAIL because the current widgets still use horizontal scrolling containers.

- [ ] **Step 3: Write minimal implementation**

```dart
// Replace the horizontal ListView date strip with a Row-based equal-width layout.
// Replace the horizontally scrolling Table with a LayoutBuilder-driven grid.
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `flutter test test/features/schedule/schedule_grid_test.dart test/features/schedule/schedule_page_test.dart`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add docs/superpowers/plans/2026-04-05-responsive-native-schedule-page.md test/features/schedule/schedule_grid_test.dart test/features/schedule/schedule_page_test.dart lib/features/schedule/pages/schedule_page.dart lib/features/schedule/widgets/schedule_grid.dart
git commit -m "feat: make native schedule page responsive"
```

### Task 2: Rebuild the top date strip as a fixed seven-column bar

**Files:**
- Modify: `lib/features/schedule/pages/schedule_page.dart`
- Test: `test/features/schedule/schedule_page_test.dart`

- [ ] **Step 1: Implement fixed seven-column date tiles**

```dart
Row(
  children: [
    for (var index = 0; index < weekDates.length; index++)
      Expanded(
        child: Padding(
          padding: EdgeInsets.only(left: index == 0 ? 0 : 6),
          child: _DateTile(...),
        ),
      ),
  ],
)
```

- [ ] **Step 2: Keep week switching behavior**

```dart
onTap: () => onDateTap(index + 1)
```

- [ ] **Step 3: Re-run page tests**

Run: `flutter test test/features/schedule/schedule_page_test.dart`
Expected: PASS

### Task 3: Replace the fixed-width schedule table with a responsive grid

**Files:**
- Modify: `lib/features/schedule/widgets/schedule_grid.dart`
- Test: `test/features/schedule/schedule_grid_test.dart`

- [ ] **Step 1: Calculate widths from the parent constraints**

```dart
LayoutBuilder(
  builder: (context, constraints) {
    final timeColumnWidth = ...;
    final dayColumnWidth = ...;
    return ...
  },
)
```

- [ ] **Step 2: Render the header row and body rows without horizontal scrolling**

```dart
Column(
  children: [
    Row(children: [...]),
    for (var rowIndex = 0; rowIndex < _lessonLabels.length; rowIndex++)
      SizedBox(
        height: rowHeight,
        child: Row(children: [...]),
      ),
  ],
)
```

- [ ] **Step 3: Compress course-card spacing and typography based on column width**

```dart
final compact = dayColumnWidth < 52;
```

- [ ] **Step 4: Re-run grid tests**

Run: `flutter test test/features/schedule/schedule_grid_test.dart`
Expected: PASS

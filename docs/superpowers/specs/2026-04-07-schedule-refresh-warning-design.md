# Schedule Refresh Warning Design

## Summary

When the schedule page is showing cached data because the device is offline or because the backend has marked the schedule cache as stale, the app bar should show a separate red warning action next to refresh. Tapping the warning action should explain why it is shown, while tapping refresh should keep its current behavior and trigger a refresh.

## Goals

- Warn users when the visible schedule is cached because the latest fetch failed.
- Distinguish between offline cache and stale backend cache in user-facing copy.
- Preserve the existing refresh control and sync feedback flow.

## Non-Goals

- No new full-page error surfaces beyond the existing empty-state failure screen.
- No backend API changes.
- No modal dialog flow; use lightweight in-page feedback only.

## Warning States

The schedule page will derive a single warning state with this priority:

1. `offlineCache`: a cached schedule is visible and the latest load or refresh failed due to an offline-style network error.
2. `staleCache`: the visible schedule has `isStale == true` and no newer offline state is active.
3. `none`: no warning action.

These states are client UI state and should not be stored in the `Schedule` model.

## UX

- The warning action and refresh action are separate app bar buttons.
- When the warning state is not `none`, a red exclamation action appears next to refresh.
- Tapping the warning action shows a `SnackBar` with state-specific copy:
  - `offlineCache`: `当前处于离线状态，正在显示缓存课表`
  - `staleCache`: `当前显示的是缓存课表，可能不是最新数据`
- Tapping the refresh icon still runs the existing manual refresh flow.

## State Flow

- `loadSchedule()`:
  - If cached data exists, show it immediately.
  - If the fresh fetch succeeds, clear offline warnings and fall back to `staleCache` only when `schedule.isStale` is true.
  - If the fresh fetch fails and cached data exists, keep the cached schedule and only show warning when the failure is a network/offline error or the cached schedule is already stale.
  - If the fresh fetch fails and no cached data exists, keep the existing full-page error state and do not show a warning action.
- `manualRefresh()`:
  - On success, replace the schedule and recalculate the warning from `isStale`.
  - On failure with cached data still visible, preserve the schedule and only show warning when the failure is offline or the preserved schedule is already stale.

## Testing

- Add controller tests for warning-state priority and transitions.
- Add widget tests for badge visibility, warning message copy, and refresh-button behavior while a warning is present.

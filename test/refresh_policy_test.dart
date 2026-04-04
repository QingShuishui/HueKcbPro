import 'package:flutter_test/flutter_test.dart';
import 'package:kcb_pro_android/services/refresh_policy.dart';

void main() {
  test('returns true when last refresh is older than one hour', () {
    final now = DateTime(2026, 4, 1, 12, 0, 0);
    final lastRefresh = now.subtract(const Duration(hours: 1, minutes: 1));

    expect(
      RefreshPolicy.shouldRefresh(now: now, lastRefreshAt: lastRefresh),
      isTrue,
    );
  });

  test('returns false when last refresh is within one hour window', () {
    final now = DateTime(2026, 4, 1, 12, 0, 0);
    final lastRefresh = now.subtract(const Duration(minutes: 59));

    expect(
      RefreshPolicy.shouldRefresh(now: now, lastRefreshAt: lastRefresh),
      isFalse,
    );
  });

  test('returns false when no refresh has happened yet', () {
    final now = DateTime(2026, 4, 1, 12, 0, 0);

    expect(
      RefreshPolicy.shouldRefresh(now: now, lastRefreshAt: null),
      isFalse,
    );
  });
}

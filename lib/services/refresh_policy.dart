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

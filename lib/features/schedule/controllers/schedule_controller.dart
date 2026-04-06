import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/schedule.dart';
import '../repositories/schedule_repository.dart';

class ScheduleController extends StateNotifier<AsyncValue<Schedule?>> {
  ScheduleController(this._repository) : super(const AsyncValue.data(null));

  final ScheduleRepository _repository;
  bool _isRefreshing = false;
  static const _refreshPollAttempts = 8;
  static const _refreshPollInterval = Duration(milliseconds: 400);

  bool get isRefreshing => _isRefreshing;

  Future<void> loadSchedule() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(_repository.fetchCurrentSchedule);
  }

  Future<void> manualRefresh() async {
    _isRefreshing = true;
    final previous = state.valueOrNull;
    try {
      await _repository.refreshFromAcademicSystem();
      final refreshed = await _waitForUpdatedSchedule(previous);
      state = AsyncValue.data(refreshed);
    } catch (error, stackTrace) {
      if (previous != null) {
        state = AsyncValue.data(previous);
      } else {
        state = AsyncValue.error(error, stackTrace);
      }
    } finally {
      _isRefreshing = false;
    }
  }

  Future<Schedule> _waitForUpdatedSchedule(Schedule? previous) async {
    final fallback = await _repository.fetchCurrentSchedule();
    if (previous == null || _hasScheduleUpdated(previous, fallback)) {
      return fallback;
    }

    Schedule latest = fallback;
    for (var attempt = 1; attempt < _refreshPollAttempts; attempt++) {
      await Future<void>.delayed(_refreshPollInterval);
      latest = await _repository.fetchCurrentSchedule();
      if (_hasScheduleUpdated(previous, latest)) {
        return latest;
      }
    }
    return latest;
  }

  bool _hasScheduleUpdated(Schedule previous, Schedule next) {
    return previous.generatedAt != next.generatedAt ||
        previous.lastSyncedAt != next.lastSyncedAt;
  }
}

final scheduleRepositoryProvider = Provider<ScheduleRepository>((ref) {
  return ScheduleRepository();
});

final scheduleControllerProvider =
    StateNotifierProvider<ScheduleController, AsyncValue<Schedule?>>((ref) {
      return ScheduleController(ref.watch(scheduleRepositoryProvider));
    });

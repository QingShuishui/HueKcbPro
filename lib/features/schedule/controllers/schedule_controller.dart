import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/schedule.dart';
import '../repositories/schedule_repository.dart';

class ScheduleController extends StateNotifier<AsyncValue<Schedule?>> {
  ScheduleController(this._repository) : super(const AsyncValue.data(null));

  final ScheduleRepository _repository;
  bool _isRefreshing = false;

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
      final refreshed = await _repository.fetchCurrentSchedule();
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
}

final scheduleRepositoryProvider = Provider<ScheduleRepository>((ref) {
  return ScheduleRepository();
});

final scheduleControllerProvider =
    StateNotifierProvider<ScheduleController, AsyncValue<Schedule?>>((ref) {
      return ScheduleController(ref.watch(scheduleRepositoryProvider));
    });

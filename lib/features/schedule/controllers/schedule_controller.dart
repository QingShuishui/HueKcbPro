import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/schedule.dart';
import '../repositories/schedule_repository.dart';

enum ScheduleRefreshWarning { none, staleCache, offlineCache }

enum ScheduleManualRefreshResult { updated, stillSyncing, failed }

class ScheduleController extends StateNotifier<AsyncValue<Schedule?>> {
  ScheduleController(
    this._ref,
    this._repository, {
    this.refreshPollTimeout = const Duration(seconds: 10),
    this.refreshPollInterval = const Duration(milliseconds: 400),
  }) : super(const AsyncValue.data(null));

  final Ref _ref;
  final ScheduleRepository _repository;
  final Duration refreshPollTimeout;
  final Duration refreshPollInterval;
  bool _isRefreshing = false;

  bool get isRefreshing => _isRefreshing;

  Future<void> loadSchedule() async {
    final cached = await _repository.readCachedSchedule();
    if (cached != null) {
      state = AsyncValue.data(cached);
      _setWarningFromSchedule(cached);
    } else {
      state = const AsyncValue.loading();
      _clearWarning();
    }

    try {
      final fresh = await _repository.fetchCurrentSchedule();
      state = AsyncValue.data(fresh);
      _setWarningFromSchedule(fresh);
    } catch (error, stackTrace) {
      if (cached == null) {
        state = AsyncValue.error(error, stackTrace);
        _clearWarning();
      } else {
        _setWarningFromFailure(error, fallbackSchedule: cached);
      }
    }
  }

  Future<ScheduleManualRefreshResult> manualRefresh() async {
    _isRefreshing = true;
    final previous = state.valueOrNull;
    try {
      var baseline = previous;
      if (previous != null) {
        try {
          baseline = await _repository.fetchCurrentSchedule();
          state = AsyncValue.data(baseline);
          _setWarningFromSchedule(baseline);
        } catch (_) {
          baseline = previous;
        }
      }
      await _repository.refreshFromAcademicSystem();
      final refreshed = await _waitForUpdatedSchedule(baseline);
      if (refreshed == null) {
        return ScheduleManualRefreshResult.stillSyncing;
      }
      state = AsyncValue.data(refreshed);
      _setWarningFromSchedule(refreshed);
      return ScheduleManualRefreshResult.updated;
    } catch (error, stackTrace) {
      if (previous != null) {
        state = AsyncValue.data(previous);
        _setWarningFromFailure(error, fallbackSchedule: previous);
      } else {
        state = AsyncValue.error(error, stackTrace);
        _clearWarning();
      }
      return ScheduleManualRefreshResult.failed;
    } finally {
      _isRefreshing = false;
    }
  }

  Future<Schedule?> _waitForUpdatedSchedule(Schedule? previous) async {
    final fallback = await _repository.fetchCurrentSchedule();
    if (previous == null || _hasScheduleUpdated(previous, fallback)) {
      return fallback;
    }

    final deadline = DateTime.now().add(refreshPollTimeout);
    while (DateTime.now().isBefore(deadline)) {
      final remaining = deadline.difference(DateTime.now());
      if (remaining <= Duration.zero) {
        break;
      }
      await Future<void>.delayed(
        remaining < refreshPollInterval ? remaining : refreshPollInterval,
      );
      final latest = await _repository.fetchCurrentSchedule();
      if (_hasScheduleUpdated(previous, latest)) {
        return latest;
      }
    }
    return null;
  }

  bool _hasScheduleUpdated(Schedule previous, Schedule next) {
    return previous.generatedAt != next.generatedAt ||
        previous.lastSyncedAt != next.lastSyncedAt;
  }

  void _setWarningFromSchedule(Schedule? schedule) {
    if (schedule?.isStale ?? false) {
      _setWarning(ScheduleRefreshWarning.staleCache);
      return;
    }
    _clearWarning();
  }

  void _setWarningFromFailure(Object error, {Schedule? fallbackSchedule}) {
    if (_isOfflineError(error)) {
      _setWarning(ScheduleRefreshWarning.offlineCache);
      return;
    }
    _setWarningFromSchedule(fallbackSchedule);
  }

  void _clearWarning() {
    _setWarning(ScheduleRefreshWarning.none);
  }

  void _setWarning(ScheduleRefreshWarning warning) {
    _ref.read(scheduleRefreshWarningProvider.notifier).state = warning;
  }

  bool _isOfflineError(Object error) {
    if (error is SocketException) {
      return true;
    }
    if (error is DioException) {
      return error.type == DioExceptionType.connectionError ||
          error.error is SocketException;
    }
    return false;
  }
}

final scheduleRepositoryProvider = Provider<ScheduleRepository>((ref) {
  return ScheduleRepository();
});

final scheduleRefreshWarningProvider = StateProvider<ScheduleRefreshWarning>((
  ref,
) {
  return ScheduleRefreshWarning.none;
});

final scheduleControllerProvider =
    StateNotifierProvider<ScheduleController, AsyncValue<Schedule?>>((ref) {
      return ScheduleController(ref, ref.watch(scheduleRepositoryProvider));
    });

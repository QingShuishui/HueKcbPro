import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../storage/schedule_display_settings_store.dart';

export '../storage/schedule_display_settings_store.dart';

class ScheduleDisplaySettingsController
    extends StateNotifier<ScheduleDisplaySettings> {
  ScheduleDisplaySettingsController(this._store)
    : super(const ScheduleDisplaySettings()) {
    _load();
  }

  final ScheduleDisplaySettingsStore _store;

  Future<void> _load() async {
    state = await _store.read();
  }

  Future<void> setExpandCourseDetails(bool value) async {
    final next = state.copyWith(expandCourseDetails: value);
    state = next;
    await _store.write(next);
  }
}

final scheduleDisplaySettingsProvider =
    StateNotifierProvider<
      ScheduleDisplaySettingsController,
      ScheduleDisplaySettings
    >((ref) {
      return ScheduleDisplaySettingsController(
        FileScheduleDisplaySettingsStore(),
      );
    });

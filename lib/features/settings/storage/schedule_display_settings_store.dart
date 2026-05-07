import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

class ScheduleDisplaySettings {
  const ScheduleDisplaySettings({this.expandCourseDetails = true});

  final bool expandCourseDetails;

  ScheduleDisplaySettings copyWith({bool? expandCourseDetails}) {
    return ScheduleDisplaySettings(
      expandCourseDetails: expandCourseDetails ?? this.expandCourseDetails,
    );
  }

  factory ScheduleDisplaySettings.fromJson(Map<String, dynamic> json) {
    return ScheduleDisplaySettings(
      expandCourseDetails: json['expand_course_details'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toJson() {
    return {'expand_course_details': expandCourseDetails};
  }
}

abstract class ScheduleDisplaySettingsStore {
  Future<ScheduleDisplaySettings> read();

  Future<void> write(ScheduleDisplaySettings settings);
}

class FileScheduleDisplaySettingsStore implements ScheduleDisplaySettingsStore {
  FileScheduleDisplaySettingsStore({
    Future<Directory> Function()? directoryProvider,
  }) : _directoryProvider =
           directoryProvider ?? getApplicationDocumentsDirectory;

  final Future<Directory> Function() _directoryProvider;

  Future<File> _settingsFile() async {
    final directory = await _directoryProvider();
    return File('${directory.path}/schedule-display-settings.json');
  }

  @override
  Future<ScheduleDisplaySettings> read() async {
    try {
      final file = await _settingsFile();
      if (!await file.exists()) {
        return const ScheduleDisplaySettings();
      }
      final payload =
          jsonDecode(await file.readAsString()) as Map<String, dynamic>;
      return ScheduleDisplaySettings.fromJson(payload);
    } catch (_) {
      return const ScheduleDisplaySettings();
    }
  }

  @override
  Future<void> write(ScheduleDisplaySettings settings) async {
    final file = await _settingsFile();
    await file.writeAsString(jsonEncode(settings.toJson()));
  }
}

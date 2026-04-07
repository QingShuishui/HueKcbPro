import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

import '../models/schedule.dart';

class ScheduleCacheStore {
  ScheduleCacheStore({Future<Directory> Function()? directoryProvider})
    : _directoryProvider =
          directoryProvider ?? getApplicationDocumentsDirectory;

  final Future<Directory> Function() _directoryProvider;

  Future<File> _cacheFile() async {
    final directory = await _directoryProvider();
    return File('${directory.path}/schedule-cache.json');
  }

  Future<Schedule?> read() async {
    try {
      final file = await _cacheFile();
      if (!await file.exists()) {
        return null;
      }
      final payload =
          jsonDecode(await file.readAsString()) as Map<String, dynamic>;
      return Schedule.fromJson(payload);
    } catch (_) {
      return null;
    }
  }

  Future<void> write(Schedule schedule) async {
    final file = await _cacheFile();
    await file.writeAsString(jsonEncode(schedule.toJson()));
  }
}

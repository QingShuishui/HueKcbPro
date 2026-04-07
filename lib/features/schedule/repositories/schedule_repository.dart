import 'package:dio/dio.dart';

import '../../../core/network/api_client.dart';
import '../../../core/storage/session_storage.dart';
import '../models/schedule.dart';
import '../storage/schedule_cache_store.dart';

class ScheduleRepository {
  ScheduleRepository({ApiClient? apiClient, SessionStorage? storage})
    : _apiClient = apiClient ?? ApiClient(),
      _storage = storage ?? SessionStorage(),
      _cacheStore = ScheduleCacheStore();

  final ApiClient _apiClient;
  final SessionStorage _storage;
  final ScheduleCacheStore _cacheStore;

  Future<Schedule?> readCachedSchedule() => _cacheStore.read();

  Future<Schedule> fetchCurrentSchedule() async {
    final accessToken = await _storage.readAccessToken();
    final response = await _apiClient.dio.get<Map<String, dynamic>>(
      '/schedule/current',
      options: accessToken == null
          ? null
          : Options(headers: {'Authorization': 'Bearer $accessToken'}),
    );
    final schedule = Schedule.fromJson(response.data!);
    await _cacheStore.write(schedule);
    return schedule;
  }

  Future<void> refreshFromAcademicSystem() async {
    final accessToken = await _storage.readAccessToken();
    await _apiClient.dio.post<void>(
      '/schedule/refresh',
      options: accessToken == null
          ? null
          : Options(headers: {'Authorization': 'Bearer $accessToken'}),
    );
  }
}

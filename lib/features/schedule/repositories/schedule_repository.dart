import 'package:dio/dio.dart';

import '../../../core/network/api_client.dart';
import '../../../core/storage/session_storage.dart';
import '../models/schedule.dart';

class ScheduleRepository {
  ScheduleRepository({ApiClient? apiClient, SessionStorage? storage})
    : _apiClient = apiClient ?? ApiClient(),
      _storage = storage ?? SessionStorage();

  final ApiClient _apiClient;
  final SessionStorage _storage;

  Future<Schedule> fetchCurrentSchedule() async {
    final accessToken = await _storage.readAccessToken();
    final response = await _apiClient.dio.get<Map<String, dynamic>>(
      '/schedule/current',
      options: accessToken == null
          ? null
          : Options(
              headers: {'Authorization': 'Bearer $accessToken'},
            ),
    );
    return Schedule.fromJson(response.data!);
  }

  Future<void> refreshFromAcademicSystem() async {
    final accessToken = await _storage.readAccessToken();
    await _apiClient.dio.post<void>(
      '/schedule/refresh',
      options: accessToken == null
          ? null
          : Options(
              headers: {'Authorization': 'Bearer $accessToken'},
            ),
    );
  }
}

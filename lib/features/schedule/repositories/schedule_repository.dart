import 'package:dio/dio.dart';

import '../../../core/network/api_client.dart';
import '../../../core/storage/session_storage.dart';
import '../../auth/repositories/auth_repository.dart';
import '../models/schedule.dart';
import '../storage/schedule_cache_store.dart';

class ScheduleRepository {
  ScheduleRepository({
    ApiClient? apiClient,
    SessionStorage? storage,
    AuthRepository? authRepository,
  }) : _apiClient = apiClient ?? ApiClient(),
       _storage = storage ?? SessionStorage(),
       _authRepository =
           authRepository ??
           AuthRepository(apiClient: apiClient, storage: storage),
       _cacheStore = ScheduleCacheStore();

  final ApiClient _apiClient;
  final SessionStorage _storage;
  final AuthRepository _authRepository;
  final ScheduleCacheStore _cacheStore;

  Future<Schedule?> readCachedSchedule() => _cacheStore.read();

  Future<Schedule> fetchCurrentSchedule() async {
    final response = await _sendWithSessionRefreshRetry<Map<String, dynamic>>(
      (options) => _apiClient.dio.get<Map<String, dynamic>>(
        '/schedule/current',
        options: options,
      ),
    );
    final schedule = Schedule.fromJson(response.data!);
    await _cacheStore.write(schedule);
    return schedule;
  }

  Future<void> refreshFromAcademicSystem() async {
    await _sendWithSessionRefreshRetry<void>(
      (options) =>
          _apiClient.dio.post<void>('/schedule/refresh', options: options),
    );
  }

  Future<Response<T>> _sendWithSessionRefreshRetry<T>(
    Future<Response<T>> Function(Options? options) send,
  ) async {
    try {
      return await send(await _authOptions());
    } on DioException catch (error) {
      if (!_isUnauthorized(error) || !await _refreshStoredSession()) {
        rethrow;
      }
      return send(await _authOptions());
    }
  }

  Future<Options?> _authOptions() async {
    final accessToken = await _storage.readAccessToken();
    if (accessToken == null) {
      return null;
    }
    return Options(headers: {'Authorization': 'Bearer $accessToken'});
  }

  Future<bool> _refreshStoredSession() async {
    final storedUser = await _authRepository.readStoredUser();
    if (storedUser == null) {
      return false;
    }
    final result = await _authRepository.refreshSessionSilently(storedUser);
    return result == SessionRefreshResult.refreshed;
  }

  bool _isUnauthorized(DioException error) {
    return error.response?.statusCode == 401;
  }
}

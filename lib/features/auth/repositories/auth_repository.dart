import 'package:dio/dio.dart';

import '../../../core/network/api_client.dart';
import '../../../core/storage/session_storage.dart';
import '../models/login_response.dart';

class AuthException implements Exception {
  AuthException(this.message);

  final String message;

  @override
  String toString() => message;
}

class AuthRepository {
  AuthRepository({
    ApiClient? apiClient,
    SessionStorage? storage,
  }) : _apiClient = apiClient ?? ApiClient(),
       _storage = storage ?? SessionStorage();

  final ApiClient _apiClient;
  final SessionStorage _storage;

  Future<LoginResponse> login({
    required String academicUsername,
    required String password,
  }) async {
    try {
      final response = await _apiClient.dio.post<Map<String, dynamic>>(
        '/auth/login',
        data: {
          'school_code': 'hue',
          'academic_username': academicUsername,
          'password': password,
          'device_name': 'flutter-client',
        },
      );

      final result = LoginResponse.fromJson(response.data!);
      await _storage.saveTokens(
        result.tokens.accessToken,
        result.tokens.refreshToken,
      );
      await _storage.saveUser(result.user);
      return result;
    } on DioException catch (error) {
      final data = error.response?.data;
      if (data is Map<String, dynamic>) {
        final message = data['message'] as String?;
        if (message != null && message.isNotEmpty) {
          throw AuthException(message);
        }
      }
      throw AuthException('登录失败，请稍后重试');
    }
  }

  Future<LoginUser?> restoreSession() async {
    final refreshToken = await _storage.readRefreshToken();
    final storedUser = await _storage.readUser();
    if (refreshToken == null || storedUser == null) {
      return null;
    }

    try {
      final response = await _apiClient.dio.post<Map<String, dynamic>>(
        '/auth/refresh',
        data: {'refresh_token': refreshToken},
      );

      final json = response.data!;
      await _storage.saveTokens(
        json['access_token'] as String,
        json['refresh_token'] as String,
      );
      await _storage.saveUser(storedUser);
      return storedUser;
    } on DioException {
      await _storage.clear();
      return null;
    }
  }

  Future<void> logout() async {
    await _storage.clear();
  }
}

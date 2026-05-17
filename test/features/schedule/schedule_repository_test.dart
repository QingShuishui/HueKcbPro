import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kcb_pro_android/core/network/api_client.dart';
import 'package:kcb_pro_android/core/storage/session_storage.dart';
import 'package:kcb_pro_android/features/auth/models/login_response.dart';
import 'package:kcb_pro_android/features/auth/repositories/auth_repository.dart';
import 'package:kcb_pro_android/features/schedule/repositories/schedule_repository.dart';

void main() {
  test(
    'refreshFromAcademicSystem refreshes expired session and retries once',
    () async {
      final storage = _FakeSessionStorage();
      final authRepository = _RefreshingAuthRepository(storage);
      final dio = _retryingDio(
        successfulPath: '/schedule/refresh',
        seenAuthorizationHeaders: storage.seenAuthorizationHeaders,
      );
      final repository = ScheduleRepository(
        apiClient: ApiClient(dio: dio),
        storage: storage,
        authRepository: authRepository,
      );

      await repository.refreshFromAcademicSystem();

      expect(authRepository.refreshCalls, 1);
      expect(storage.seenAuthorizationHeaders, [
        'Bearer expired-access',
        'Bearer fresh-access',
      ]);
    },
  );
}

Dio _retryingDio({
  required String successfulPath,
  required List<String?> seenAuthorizationHeaders,
}) {
  final dio = Dio(BaseOptions(baseUrl: 'https://example.invalid'));
  var requestCount = 0;
  dio.interceptors.add(
    InterceptorsWrapper(
      onRequest: (options, handler) {
        requestCount += 1;
        seenAuthorizationHeaders.add(
          options.headers['Authorization'] as String?,
        );
        if (requestCount == 1) {
          handler.reject(
            DioException(
              requestOptions: options,
              response: Response<void>(
                requestOptions: options,
                statusCode: 401,
              ),
              type: DioExceptionType.badResponse,
            ),
          );
          return;
        }
        expect(options.path, successfulPath);
        handler.resolve(
          Response<void>(requestOptions: options, statusCode: 202),
        );
      },
    ),
  );
  return dio;
}

class _FakeSessionStorage extends SessionStorage {
  String accessToken = 'expired-access';
  final seenAuthorizationHeaders = <String?>[];

  @override
  Future<String?> readAccessToken() async => accessToken;

  @override
  Future<void> saveTokens(String accessToken, String refreshToken) async {
    this.accessToken = accessToken;
  }
}

class _RefreshingAuthRepository extends AuthRepository {
  _RefreshingAuthRepository(this._storage);

  final _FakeSessionStorage _storage;
  int refreshCalls = 0;

  @override
  Future<LoginUser?> readStoredUser() async {
    return const LoginUser(
      id: 1,
      schoolCode: 'hue',
      academicUsername: 'demo_student_id',
    );
  }

  @override
  Future<SessionRefreshResult> refreshSessionSilently(
    LoginUser storedUser,
  ) async {
    refreshCalls += 1;
    await _storage.saveTokens('fresh-access', 'fresh-refresh');
    return SessionRefreshResult.refreshed;
  }
}

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kcb_pro_android/features/auth/controllers/auth_controller.dart';
import 'package:kcb_pro_android/features/auth/models/login_response.dart';
import 'package:kcb_pro_android/features/auth/models/session_tokens.dart';
import 'package:kcb_pro_android/features/auth/repositories/auth_repository.dart';

class FakeAuthRepository extends AuthRepository {
  @override
  Future<LoginResponse> login({
    required String academicUsername,
    required String password,
  }) async {
    return LoginResponse(
      tokens: const SessionTokens(
        accessToken: 'access',
        refreshToken: 'refresh',
        tokenType: 'bearer',
      ),
      user: const LoginUser(
        id: 1,
        schoolCode: 'hue',
        academicUsername: 'demo_student_id',
      ),
    );
  }
}

class RestoringAuthRepository extends AuthRepository {
  RestoringAuthRepository(
    this._user, {
    this.hasRefreshToken = true,
    this.refreshResult = SessionRefreshResult.refreshed,
  });

  final LoginUser? _user;
  final bool hasRefreshToken;
  final SessionRefreshResult refreshResult;

  @override
  Future<LoginUser?> readStoredUser() async {
    return _user;
  }

  @override
  Future<bool> hasStoredRefreshToken() async => hasRefreshToken;

  @override
  Future<SessionRefreshResult> refreshSessionSilently(
    LoginUser storedUser,
  ) async {
    return refreshResult;
  }
}

void main() {
  test('login transitions auth state to signed in', () async {
    final container = ProviderContainer(
      overrides: [
        authRepositoryProvider.overrideWithValue(FakeAuthRepository()),
      ],
    );
    addTearDown(container.dispose);

    await container
        .read(authControllerProvider.notifier)
        .login(academicUsername: 'demo_student_id', password: 'pw123');

    expect(container.read(authControllerProvider).status, AuthStatus.signedIn);
    expect(
      container.read(authControllerProvider).user?.academicUsername,
      'demo_student_id',
    );
  });

  test('restoreSession signs user in when stored session is valid', () async {
    final container = ProviderContainer(
      overrides: [
        authRepositoryProvider.overrideWithValue(
          RestoringAuthRepository(
            const LoginUser(
              id: 1,
              schoolCode: 'hue',
              academicUsername: 'demo_student_id',
            ),
          ),
        ),
      ],
    );
    addTearDown(container.dispose);

    await container.read(authControllerProvider.notifier).restoreSession();

    expect(container.read(authControllerProvider).status, AuthStatus.signedIn);
  });

  test(
    'restoreSession keeps user signed in when refresh fails offline',
    () async {
      final container = ProviderContainer(
        overrides: [
          authRepositoryProvider.overrideWithValue(
            RestoringAuthRepository(
              const LoginUser(
                id: 1,
                schoolCode: 'hue',
                academicUsername: 'demo_student_id',
              ),
              refreshResult: SessionRefreshResult.retainedLocal,
            ),
          ),
        ],
      );
      addTearDown(container.dispose);

      await container.read(authControllerProvider.notifier).restoreSession();

      expect(
        container.read(authControllerProvider).status,
        AuthStatus.signedIn,
      );
    },
  );

  test('restoreSession signs user out when no valid session exists', () async {
    final container = ProviderContainer(
      overrides: [
        authRepositoryProvider.overrideWithValue(RestoringAuthRepository(null)),
      ],
    );
    addTearDown(container.dispose);

    await container.read(authControllerProvider.notifier).restoreSession();

    expect(container.read(authControllerProvider).status, AuthStatus.signedOut);
  });
}

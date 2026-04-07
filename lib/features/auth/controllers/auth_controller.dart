import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/login_response.dart';
import '../repositories/auth_repository.dart';

enum AuthStatus { loading, signedOut, signedIn }

class AuthState {
  const AuthState({required this.status, this.user, this.errorMessage});

  final AuthStatus status;
  final LoginUser? user;
  final String? errorMessage;

  AuthState copyWith({
    AuthStatus? status,
    LoginUser? user,
    String? errorMessage,
    bool clearError = false,
  }) {
    return AuthState(
      status: status ?? this.status,
      user: user ?? this.user,
      errorMessage: clearError ? null : errorMessage ?? this.errorMessage,
    );
  }
}

class AuthController extends StateNotifier<AuthState> {
  AuthController(this._repository)
    : super(const AuthState(status: AuthStatus.signedOut));

  final AuthRepository _repository;

  Future<void> login({
    required String academicUsername,
    required String password,
  }) async {
    state = state.copyWith(status: AuthStatus.loading, clearError: true);
    try {
      final response = await _repository.login(
        academicUsername: academicUsername,
        password: password,
      );
      state = AuthState(status: AuthStatus.signedIn, user: response.user);
    } on AuthException catch (error) {
      state = AuthState(
        status: AuthStatus.signedOut,
        errorMessage: error.message,
      );
    }
  }

  Future<void> logout() async {
    try {
      await _repository.logout();
    } finally {
      state = const AuthState(status: AuthStatus.signedOut);
    }
  }

  void debugSignInForTest({required String academicUsername}) {
    state = AuthState(
      status: AuthStatus.signedIn,
      user: LoginUser(
        id: 1,
        schoolCode: 'hue',
        academicUsername: academicUsername,
      ),
    );
  }

  Future<void> restoreSession() async {
    state = state.copyWith(status: AuthStatus.loading, clearError: true);
    final storedUser = await _repository.readStoredUser();
    final hasRefreshToken = await _repository.hasStoredRefreshToken();
    if (storedUser == null || !hasRefreshToken) {
      state = const AuthState(status: AuthStatus.signedOut);
      return;
    }

    state = AuthState(status: AuthStatus.signedIn, user: storedUser);
    final refreshResult = await _repository.refreshSessionSilently(storedUser);
    if (refreshResult == SessionRefreshResult.invalid) {
      state = const AuthState(status: AuthStatus.signedOut);
    }
  }
}

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepository();
});

final authControllerProvider = StateNotifierProvider<AuthController, AuthState>(
  (ref) {
    return AuthController(ref.watch(authRepositoryProvider));
  },
);

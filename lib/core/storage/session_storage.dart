import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../features/auth/models/login_response.dart';

class SessionStorage {
  static const _storage = FlutterSecureStorage();
  static const _accessTokenKey = 'access_token';
  static const _refreshTokenKey = 'refresh_token';
  static const _userKey = 'login_user';

  Future<void> saveTokens(String accessToken, String refreshToken) async {
    await _storage.write(key: _accessTokenKey, value: accessToken);
    await _storage.write(key: _refreshTokenKey, value: refreshToken);
  }

  Future<String?> readAccessToken() => _storage.read(key: _accessTokenKey);

  Future<String?> readRefreshToken() => _storage.read(key: _refreshTokenKey);

  Future<void> saveUser(LoginUser user) async {
    await _storage.write(
      key: _userKey,
      value: jsonEncode({
        'id': user.id,
        'school_code': user.schoolCode,
        'academic_username': user.academicUsername,
      }),
    );
  }

  Future<LoginUser?> readUser() async {
    final value = await _storage.read(key: _userKey);
    if (value == null) {
      return null;
    }

    return LoginUser.fromJson(jsonDecode(value) as Map<String, dynamic>);
  }

  Future<void> clear() => _storage.deleteAll();
}

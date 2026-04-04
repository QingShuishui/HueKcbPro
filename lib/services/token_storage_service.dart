import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class TokenStorageService {
  static const _storage = FlutterSecureStorage();
  static const _keyToken = 'kcb_token';
  static const _keyLastWebRefreshAt = 'last_web_refresh_at';

  Future<void> saveToken(String token) async {
    await _storage.write(key: _keyToken, value: token);
  }

  Future<String?> readToken() async {
    return _storage.read(key: _keyToken);
  }

  Future<void> deleteToken() async {
    await _storage.delete(key: _keyToken);
  }

  Future<void> saveLastWebRefreshAt(DateTime timestamp) async {
    await _storage.write(
      key: _keyLastWebRefreshAt,
      value: timestamp.toUtc().toIso8601String(),
    );
  }

  Future<DateTime?> readLastWebRefreshAt() async {
    final value = await _storage.read(key: _keyLastWebRefreshAt);
    if (value == null) {
      return null;
    }

    return DateTime.tryParse(value)?.toLocal();
  }
}

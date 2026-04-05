import 'dart:io';

import 'package:flutter/foundation.dart';

class ApiBaseUrl {
  static const _override = String.fromEnvironment('API_BASE_URL');
  static const _production = 'https://api-kcb.yan06.com/api/v1';
  static const _androidDebug = 'http://10.0.2.2:8000/api/v1';
  static const _localDebug = 'http://127.0.0.1:8000/api/v1';

  static String resolve({
    String? override,
    bool? isAndroid,
    bool? isReleaseMode,
    bool? isProfileMode,
  }) {
    final explicit = (override ?? _override).trim();
    if (explicit.isNotEmpty) {
      return explicit;
    }

    final releaseMode = isReleaseMode ?? kReleaseMode;
    final profileMode = isProfileMode ?? kProfileMode;
    if (releaseMode || profileMode) {
      return _production;
    }

    final android = isAndroid ?? (!kIsWeb && Platform.isAndroid);
    return android ? _androidDebug : _localDebug;
  }

  static String resolveAndroidUpdateMetadataUrl({
    String? override,
    bool? isAndroid,
    bool? isReleaseMode,
    bool? isProfileMode,
  }) {
    return '${resolve(
      override: override,
      isAndroid: isAndroid,
      isReleaseMode: isReleaseMode,
      isProfileMode: isProfileMode,
    )}/app/update/android';
  }
}

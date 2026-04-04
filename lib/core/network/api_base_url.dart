import 'dart:io';

import 'package:flutter/foundation.dart';

class ApiBaseUrl {
  static const _override = String.fromEnvironment('API_BASE_URL');

  static String resolve({String? override, bool? isAndroid}) {
    final explicit = (override ?? _override).trim();
    if (explicit.isNotEmpty) {
      return explicit;
    }

    final android = isAndroid ?? (!kIsWeb && Platform.isAndroid);
    return android
        ? 'http://10.0.2.2:8000/api/v1'
        : 'http://127.0.0.1:8000/api/v1';
  }
}

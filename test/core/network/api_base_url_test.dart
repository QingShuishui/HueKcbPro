import 'package:flutter_test/flutter_test.dart';
import 'package:kcb_pro_android/core/network/api_base_url.dart';

void main() {
  test('uses Android emulator loopback host by default', () {
    expect(
      ApiBaseUrl.resolve(isAndroid: true),
      'http://10.0.2.2:8000/api/v1',
    );
  });

  test('uses localhost by default on non-Android platforms', () {
    expect(
      ApiBaseUrl.resolve(isAndroid: false),
      'http://127.0.0.1:8000/api/v1',
    );
  });

  test('prefers explicit dart-define override when provided', () {
    expect(
      ApiBaseUrl.resolve(
        override: 'http://192.168.1.8:8000/api/v1',
        isAndroid: true,
      ),
      'http://192.168.1.8:8000/api/v1',
    );
  });
}

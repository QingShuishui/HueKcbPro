import 'package:flutter_test/flutter_test.dart';
import 'package:kcb_pro_android/services/update_service.dart';

void main() {
  test('uses the new backend_v2 Android update endpoint', () {
    final service = UpdateService();

    expect(
      service.updateMetadataUrl,
      'http://127.0.0.1:8000/api/v1/app/update/android',
    );
  });
}

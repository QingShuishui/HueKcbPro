import 'package:flutter_test/flutter_test.dart';
import 'package:kcb_pro_android/core/network/api_base_url.dart';
import 'package:kcb_pro_android/services/update_service.dart';

void main() {
  test('uses the shared backend resolver for Android update metadata', () {
    final service = UpdateService();

    expect(
      service.updateMetadataUrl,
      ApiBaseUrl.resolveAndroidUpdateMetadataUrl(
        isAndroid: true,
        isReleaseMode: false,
        isProfileMode: false,
      ),
    );
  });
}

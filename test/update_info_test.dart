import 'package:flutter_test/flutter_test.dart';
import 'package:kcb_pro_android/models/update_info.dart';

void main() {
  test('parses update metadata from json', () {
    final info = UpdateInfo.fromJson({
      'platform': 'android',
      'version': '1.0.1',
      'build_number': 2,
      'force_update': false,
      'notes': 'Bug fixes',
      'apk_url': 'http://localhost/downloads/app.apk',
      'sha256': 'abc',
      'published_at': '2026-04-01T10:00:00Z',
    });

    expect(info.buildNumber, 2);
    expect(info.apkUrl, 'http://localhost/downloads/app.apk');
    expect(info.notes, 'Bug fixes');
  });

  test('detects newer build number correctly', () {
    final info = UpdateInfo(
      platform: 'android',
      version: '1.0.1',
      buildNumber: 2,
      forceUpdate: false,
      notes: 'Bug fixes',
      apkUrl: 'http://localhost/downloads/app.apk',
      sha256: 'abc',
      publishedAt: DateTime.parse('2026-04-01T10:00:00Z'),
    );

    expect(info.isNewerThan(localBuildNumber: 1), isTrue);
    expect(info.isNewerThan(localBuildNumber: 2), isFalse);
  });
}

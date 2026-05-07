import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kcb_pro_android/features/auth/controllers/auth_controller.dart';
import 'package:kcb_pro_android/features/auth/repositories/auth_repository.dart';
import 'package:kcb_pro_android/features/settings/controllers/schedule_display_settings_controller.dart';
import 'package:kcb_pro_android/features/settings/pages/about_page.dart';
import 'package:kcb_pro_android/features/settings/pages/settings_page.dart';
import 'package:kcb_pro_android/features/updates/update_providers.dart';
import 'package:kcb_pro_android/models/update_info.dart';
import 'package:kcb_pro_android/services/update_service.dart';

void main() {
  testWidgets('renders account fields and project actions', (tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          home: SettingsPage(
            academicUsername: 'demo_student_id',
            appVersionLabel: '1.0.0+1',
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('demo_student_id'), findsOneWidget);
    expect(find.text('课表'), findsOneWidget);
    expect(find.text('课表名称缩略显示'), findsOneWidget);
    expect(find.text('项目'), findsOneWidget);
    expect(find.text('检查更新'), findsOneWidget);
    expect(find.text('当前版本：1.0.0+1'), findsOneWidget);
    expect(find.text('GitHub'), findsOneWidget);
    expect(find.text('关于'), findsOneWidget);
    expect(find.text('重新绑定教务账号'), findsNothing);
    expect(find.text('退出登录'), findsOneWidget);
  });

  testWidgets('check update action shows latest-version dialog', (
    tester,
  ) async {
    final container = ProviderContainer(
      overrides: [
        updateServiceProvider.overrideWithValue(_FakeUpdateService()),
      ],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(
          home: SettingsPage(
            academicUsername: 'demo_student_id',
            appVersionLabel: '1.0.0+1',
          ),
        ),
      ),
    );

    await tester.tap(find.text('检查更新'));
    await tester.pumpAndSettle();

    expect(find.text('当前已是最新版本'), findsOneWidget);
  });

  testWidgets('check update action shows install button when update exists', (
    tester,
  ) async {
    final container = ProviderContainer(
      overrides: [
        updateServiceProvider.overrideWithValue(_AvailableUpdateService()),
      ],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(
          home: SettingsPage(
            academicUsername: 'demo_student_id',
            appVersionLabel: '1.0.0+1',
          ),
        ),
      ),
    );

    await tester.tap(find.text('检查更新'));
    await tester.pumpAndSettle();

    expect(find.text('发现新版本'), findsOneWidget);
    expect(find.text('立即更新'), findsOneWidget);
  });

  testWidgets('about action opens about page', (tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          home: SettingsPage(
            academicUsername: 'demo_student_id',
            appVersionLabel: '1.0.0+1',
          ),
        ),
      ),
    );

    await tester.scrollUntilVisible(find.text('关于'), 120);
    await tester.pumpAndSettle();
    await tester.tap(find.text('关于'));
    await tester.pumpAndSettle();

    expect(find.byType(AboutPage), findsOneWidget);
    expect(find.text('介绍一下我自己'), findsOneWidget);
    expect(find.textContaining('24届计科学生'), findsOneWidget);
  });

  testWidgets('logout button returns auth state to signed out', (tester) async {
    final container = ProviderContainer(
      overrides: [
        authRepositoryProvider.overrideWithValue(_FakeAuthRepository()),
      ],
    );
    addTearDown(container.dispose);
    container
        .read(authControllerProvider.notifier)
        .debugSignInForTest(academicUsername: 'demo_student_id');

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(
          home: SettingsPage(
            academicUsername: 'demo_student_id',
            appVersionLabel: '1.0.0+1',
          ),
        ),
      ),
    );

    await tester.tap(find.text('退出登录'));
    await tester.pumpAndSettle();

    expect(container.read(authControllerProvider).status, AuthStatus.signedOut);
  });

  testWidgets('toggles schedule course name abbreviation', (tester) async {
    final container = ProviderContainer(
      overrides: [
        scheduleDisplaySettingsProvider.overrideWith(
          (ref) => ScheduleDisplaySettingsController(
            _MemoryScheduleDisplaySettingsStore(),
          ),
        ),
      ],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(
          home: SettingsPage(
            academicUsername: 'demo_student_id',
            appVersionLabel: '1.0.0+1',
          ),
        ),
      ),
    );
    await tester.pump();

    expect(
      container.read(scheduleDisplaySettingsProvider).expandCourseDetails,
      isTrue,
    );

    await tester.tap(find.byType(SwitchListTile));
    await tester.pump();

    expect(
      container.read(scheduleDisplaySettingsProvider).expandCourseDetails,
      isFalse,
    );
  });
}

class _FakeAuthRepository extends AuthRepository {
  @override
  Future<void> logout() async {}
}

class _FakeUpdateService extends UpdateService {
  @override
  Future<UpdateInfo?> getAvailableUpdate() async {
    return null;
  }
}

class _AvailableUpdateService extends UpdateService {
  @override
  Future<UpdateInfo?> getAvailableUpdate() async {
    return UpdateInfo(
      platform: 'android',
      version: '2.0.1',
      buildNumber: 3,
      forceUpdate: false,
      notes: '修复一些问题',
      primaryApkUrl: 'https://example.com/app.apk',
      fallbackApkUrl: 'https://fallback.example.com/app.apk',
      sha256: 'abc',
      publishedAt: DateTime.parse('2026-04-06T10:00:00Z'),
    );
  }
}

class _MemoryScheduleDisplaySettingsStore
    implements ScheduleDisplaySettingsStore {
  ScheduleDisplaySettings _settings = const ScheduleDisplaySettings();

  @override
  Future<ScheduleDisplaySettings> read() async => _settings;

  @override
  Future<void> write(ScheduleDisplaySettings settings) async {
    _settings = settings;
  }
}

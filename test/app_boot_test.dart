import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kcb_pro_android/app.dart';
import 'package:kcb_pro_android/features/auth/controllers/auth_controller.dart';
import 'package:kcb_pro_android/features/auth/models/login_response.dart';
import 'package:kcb_pro_android/features/auth/repositories/auth_repository.dart';
import 'package:kcb_pro_android/features/schedule/controllers/schedule_controller.dart';
import 'package:kcb_pro_android/features/schedule/models/course.dart';
import 'package:kcb_pro_android/features/schedule/models/schedule.dart';
import 'package:kcb_pro_android/features/schedule/repositories/schedule_repository.dart';
import 'package:kcb_pro_android/features/updates/update_providers.dart';
import 'package:kcb_pro_android/models/update_info.dart';
import 'package:kcb_pro_android/services/update_service.dart';

class _BootAuthRepository extends AuthRepository {
  _BootAuthRepository(this._user);

  final LoginUser? _user;

  @override
  Future<LoginUser?> restoreSession() async {
    return _user;
  }
}

class _BootScheduleRepository extends ScheduleRepository {
  @override
  Future<Schedule> fetchCurrentSchedule() async {
    return Schedule(
      semesterLabel: '2026春',
      generatedAt: DateTime.parse('2026-04-04T10:00:00Z'),
      isStale: false,
      lastSyncedAt: DateTime.parse('2026-04-04T10:00:00Z'),
      courses: const [
        Course(
          name: '软件测试技术',
          code: 'SIT',
          teacher: '张三',
          room: 'S4409',
          weekday: 1,
          lessonStart: 1,
          lessonEnd: 2,
          rawWeeks: '1-16(周)',
          parsedWeeks: [1, 2, 3],
        ),
      ],
    );
  }
}

void main() {
  testWidgets('shows login page when no session exists', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authRepositoryProvider.overrideWithValue(_BootAuthRepository(null)),
          scheduleRepositoryProvider.overrideWithValue(
            _BootScheduleRepository(),
          ),
          updateServiceProvider.overrideWithValue(_NoopUpdateService()),
        ],
        child: KcbApp(),
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('HUE课程表Pro'), findsOneWidget);
  });

  testWidgets('shows schedule page when stored session is restored', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authRepositoryProvider.overrideWithValue(
            _BootAuthRepository(
              const LoginUser(
                id: 1,
                schoolCode: 'hue',
                academicUsername: 'demo_student_id',
              ),
            ),
          ),
          scheduleRepositoryProvider.overrideWithValue(
            _BootScheduleRepository(),
          ),
          updateServiceProvider.overrideWithValue(_NoopUpdateService()),
        ],
        child: KcbApp(),
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.textContaining('第'), findsWidgets);
  });

  testWidgets('shows update dialog on app boot when update is available', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authRepositoryProvider.overrideWithValue(_BootAuthRepository(null)),
          scheduleRepositoryProvider.overrideWithValue(
            _BootScheduleRepository(),
          ),
          updateServiceProvider.overrideWithValue(_BootUpdateService()),
        ],
        child: KcbApp(),
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('发现新版本'), findsOneWidget);
    expect(find.text('立即更新'), findsOneWidget);
  });
}

class _BootUpdateService extends UpdateService {
  @override
  Future<UpdateInfo?> getAvailableUpdate() async {
    return UpdateInfo(
      platform: 'android',
      version: '2.0.1',
      buildNumber: 3,
      forceUpdate: false,
      notes: '启动时检测到新版本',
      primaryApkUrl: 'https://example.com/app.apk',
      fallbackApkUrl: 'https://fallback.example.com/app.apk',
      sha256: 'abc',
      publishedAt: DateTime.parse('2026-04-06T10:00:00Z'),
    );
  }
}

class _NoopUpdateService extends UpdateService {
  @override
  Future<UpdateInfo?> getAvailableUpdate() async {
    return null;
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kcb_pro_android/features/auth/controllers/auth_controller.dart';
import 'package:kcb_pro_android/features/auth/models/login_response.dart';
import 'package:kcb_pro_android/features/auth/pages/login_page.dart';
import 'package:kcb_pro_android/features/auth/repositories/auth_repository.dart';
import 'package:kcb_pro_android/features/schedule/pages/schedule_page.dart';

void main() {
  testWidgets('shows HUE课程表Pro branding', (tester) async {
    await tester.pumpWidget(
      const ProviderScope(child: MaterialApp(home: LoginPage())),
    );

    expect(find.text('HUE课程表Pro'), findsOneWidget);
    expect(find.text('湖北第二师范学院课表'), findsOneWidget);
    expect(find.text('Tip :) 密码默认为您的出生日期'), findsOneWidget);
  });

  testWidgets('shows validation message when fields are empty', (tester) async {
    await tester.pumpWidget(
      const ProviderScope(child: MaterialApp(home: LoginPage())),
    );

    await tester.tap(find.text('登录'));
    await tester.pump();

    expect(find.text('请输入学号'), findsOneWidget);
    expect(find.text('请输入密码，默认为您的出生日期'), findsOneWidget);
  });

  testWidgets('shows login error message when repository throws', (
    tester,
  ) async {
    final container = ProviderContainer(
      overrides: [
        authRepositoryProvider.overrideWithValue(_ThrowingAuthRepository()),
      ],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: LoginPage()),
      ),
    );

    await tester.enterText(find.byType(TextFormField).at(0), 'demo_student_id');
    await tester.enterText(find.byType(TextFormField).at(1), 'pw123');
    await tester.tap(find.text('登录'));
    await tester.pumpAndSettle();

    expect(find.text('账号或密码错误'), findsOneWidget);
  });

  testWidgets('opens local debug schedule with debug credentials', (
    tester,
  ) async {
    final repository = _TrackingAuthRepository();
    final container = ProviderContainer(
      overrides: [authRepositoryProvider.overrideWithValue(repository)],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: LoginPage()),
      ),
    );

    await tester.enterText(find.byType(TextFormField).at(0), 'debug');
    await tester.enterText(find.byType(TextFormField).at(1), 'debug');
    await tester.tap(find.text('登录'));
    await tester.pumpAndSettle();

    expect(repository.loginCalls, 0);
    expect(find.byType(SchedulePage), findsOneWidget);
    expect(find.textContaining('超长课程名称'), findsWidgets);
  });
}

class _ThrowingAuthRepository extends AuthRepository {
  @override
  Future<LoginResponse> login({
    required String academicUsername,
    required String password,
  }) async {
    throw AuthException('账号或密码错误');
  }
}

class _TrackingAuthRepository extends AuthRepository {
  int loginCalls = 0;

  @override
  Future<LoginResponse> login({
    required String academicUsername,
    required String password,
  }) async {
    loginCalls += 1;
    throw AuthException('不应该调用真实登录');
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kcb_pro_android/features/auth/controllers/auth_controller.dart';
import 'package:kcb_pro_android/features/auth/repositories/auth_repository.dart';
import 'package:kcb_pro_android/features/settings/pages/settings_page.dart';

void main() {
  testWidgets('renders account fields without unused rebind action', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: SettingsPage(academicUsername: 'demo_student_id'),
      ),
    );

    expect(find.text('demo_student_id'), findsOneWidget);
    expect(find.text('重新绑定教务账号'), findsNothing);
    expect(find.text('退出登录'), findsOneWidget);
  });

  testWidgets('logout button returns auth state to signed out', (tester) async {
    final container = ProviderContainer(
      overrides: [
        authRepositoryProvider.overrideWithValue(_FakeAuthRepository()),
      ],
    );
    addTearDown(container.dispose);
    container.read(authControllerProvider.notifier).debugSignInForTest(
      academicUsername: 'demo_student_id',
    );

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(
          home: SettingsPage(academicUsername: 'demo_student_id'),
        ),
      ),
    );

    await tester.tap(find.text('退出登录'));
    await tester.pumpAndSettle();

    expect(container.read(authControllerProvider).status, AuthStatus.signedOut);
  });
}

class _FakeAuthRepository extends AuthRepository {
  @override
  Future<void> logout() async {}
}

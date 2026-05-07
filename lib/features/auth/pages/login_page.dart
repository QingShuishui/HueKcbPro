import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../schedule/debug/debug_schedule.dart';
import '../../schedule/pages/schedule_page.dart';
import '../controllers/auth_controller.dart';

class LoginPage extends ConsumerStatefulWidget {
  const LoginPage({super.key});

  @override
  ConsumerState<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends ConsumerState<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authControllerProvider);

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFFFFF1F7), Color(0xFFFDFBF7)],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 440),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.9),
                    borderRadius: BorderRadius.circular(28),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x14000000),
                        blurRadius: 24,
                        offset: Offset(0, 12),
                      ),
                    ],
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(28),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'HUE课程表Pro',
                            style: Theme.of(context).textTheme.headlineMedium
                                ?.copyWith(
                                  fontWeight: FontWeight.w900,
                                  color: const Color(0xFFF472B6),
                                ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            '湖北第二师范学院课表',
                            style: Theme.of(context).textTheme.titleMedium
                                ?.copyWith(
                                  fontWeight: FontWeight.w700,
                                  color: const Color(0xFF6B7280),
                                ),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            '登录后可实时查看课表，获取教务系统最新课表。',
                            style: Theme.of(context).textTheme.bodyMedium
                                ?.copyWith(
                                  color: const Color(0xFF9CA3AF),
                                  height: 1.45,
                                ),
                          ),
                          const SizedBox(height: 28),
                          TextFormField(
                            controller: _usernameController,
                            decoration: const InputDecoration(labelText: '学号'),
                            validator: (value) =>
                                (value == null || value.isEmpty)
                                ? '请输入学号'
                                : null,
                          ),
                          const SizedBox(height: 12),
                          TextFormField(
                            controller: _passwordController,
                            obscureText: true,
                            decoration: const InputDecoration(labelText: '密码'),
                            validator: (value) =>
                                (value == null || value.isEmpty)
                                ? '请输入密码，默认为您的出生日期'
                                : null,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Tip :) 密码默认为您的出生日期',
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(
                                  color: const Color(0xFFFB7185),
                                  fontWeight: FontWeight.w600,
                                ),
                          ),
                          if (authState.errorMessage != null) ...[
                            const SizedBox(height: 16),
                            Text(
                              authState.errorMessage!,
                              style: TextStyle(
                                color: Theme.of(context).colorScheme.error,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                          const SizedBox(height: 24),
                          SizedBox(
                            width: double.infinity,
                            child: FilledButton(
                              onPressed: authState.status == AuthStatus.loading
                                  ? null
                                  : () async {
                                      if (!(_formKey.currentState?.validate() ??
                                          false)) {
                                        return;
                                      }

                                      if (_usernameController.text == 'debug' &&
                                          _passwordController.text == 'debug') {
                                        await Navigator.of(context).push(
                                          MaterialPageRoute(
                                            builder: (_) => SchedulePage(
                                              schedule:
                                                  debugLongContentSchedule,
                                              initialDate: DateTime(2026, 3, 2),
                                            ),
                                          ),
                                        );
                                        return;
                                      }

                                      await ref
                                          .read(authControllerProvider.notifier)
                                          .login(
                                            academicUsername:
                                                _usernameController.text,
                                            password: _passwordController.text,
                                          );
                                    },
                              child: Text(
                                authState.status == AuthStatus.loading
                                    ? '登录中...'
                                    : '登录',
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

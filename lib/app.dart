import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'features/auth/controllers/auth_controller.dart';
import 'features/auth/pages/login_page.dart';
import 'features/schedule/pages/schedule_page.dart';

class KcbApp extends ConsumerStatefulWidget {
  const KcbApp({super.key});

  @override
  ConsumerState<KcbApp> createState() => _KcbAppState();
}

class _KcbAppState extends ConsumerState<KcbApp> {
  bool _bootstrapping = true;

  @override
  void initState() {
    super.initState();
    Future.microtask(() async {
      await ref.read(authControllerProvider.notifier).restoreSession();
      if (mounted) {
        setState(() {
          _bootstrapping = false;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authControllerProvider);

    return MaterialApp(
      title: 'HUE课程表Pro',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFFF472B6),
          primary: const Color(0xFFF472B6),
          secondary: const Color(0xFFFB7185),
          surface: Colors.white,
        ),
        scaffoldBackgroundColor: const Color(0xFFFDFBF7),
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.transparent,
          foregroundColor: Color(0xFF374151),
          elevation: 0,
          centerTitle: false,
        ),
        cardTheme: const CardThemeData(
          color: Colors.white,
          elevation: 0,
          margin: EdgeInsets.zero,
        ),
      ),
      home: _bootstrapping
          ? const Scaffold(body: Center(child: CircularProgressIndicator()))
          : switch (authState.status) {
              AuthStatus.signedIn => const SchedulePage(),
              AuthStatus.loading => const Scaffold(
                  body: Center(child: CircularProgressIndicator()),
                ),
              AuthStatus.signedOut => const LoginPage(),
            },
    );
  }
}

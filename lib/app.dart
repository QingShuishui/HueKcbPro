import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'features/auth/controllers/auth_controller.dart';
import 'features/auth/pages/login_page.dart';
import 'features/schedule/pages/schedule_page.dart';
import 'features/updates/update_prompt.dart';
import 'features/updates/update_providers.dart';

class KcbApp extends ConsumerStatefulWidget {
  const KcbApp({super.key});

  @override
  ConsumerState<KcbApp> createState() => _KcbAppState();
}

class _KcbAppState extends ConsumerState<KcbApp> {
  bool _bootstrapping = true;
  bool _checkingUpdate = false;
  bool _updateCheckScheduled = false;
  bool _updatePromptShownThisSession = false;
  DateTime? _lastUpdateCheckAt;
  static const _updateCheckInterval = Duration(hours: 6);
  final GlobalKey<NavigatorState> _navigatorKey = GlobalKey<NavigatorState>();

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

    if (!_bootstrapping && authState.status != AuthStatus.loading) {
      _scheduleUpdateCheck();
    }

    return MaterialApp(
      navigatorKey: _navigatorKey,
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

  void _scheduleUpdateCheck() {
    if (_updateCheckScheduled) {
      return;
    }
    _updateCheckScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _updateCheckScheduled = false;
      final dialogContext = _navigatorKey.currentContext;
      if (dialogContext != null) {
        unawaited(_maybeCheckForUpdates(dialogContext));
      }
    });
  }

  Future<void> _maybeCheckForUpdates(BuildContext dialogContext) async {
    if (_checkingUpdate || _updatePromptShownThisSession || !mounted) {
      return;
    }

    final now = DateTime.now();
    if (_lastUpdateCheckAt != null &&
        now.difference(_lastUpdateCheckAt!) < _updateCheckInterval) {
      return;
    }

    _checkingUpdate = true;
    _lastUpdateCheckAt = now;
    try {
      final updateService = ref.read(updateServiceProvider);
      final updateInfo = await updateService.getAvailableUpdate();
      if (!mounted || updateInfo == null || _updatePromptShownThisSession) {
        return;
      }
      _updatePromptShownThisSession = true;
      await showUpdateDialog(
        context: dialogContext,
        updateInfo: updateInfo,
        updateService: updateService,
      );
    } finally {
      _checkingUpdate = false;
    }
  }
}

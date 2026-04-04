# Native Flutter Client Migration Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the current WebView-first Flutter app with a native Flutter client that authenticates against `backend_v2`, renders a native timetable, handles stale-sync states, supports credential rebinding, and preserves Android update checks.

**Architecture:** The Flutter client will move from a single WebView screen to a small feature-based structure. `flutter_riverpod` manages auth and schedule state, `dio` owns HTTP transport and token refresh, native pages render login and timetable views from structured JSON, and `UpdateService` is kept but repointed at the new backend endpoint.

**Tech Stack:** Flutter, Dart, `flutter_riverpod`, `dio`, `flutter_secure_storage`, `package_info_plus`, `path_provider`, `crypto`, widget tests, `mocktail`

---

### Task 1: Add API/session dependencies and prove login response parsing

**Files:**
- Modify: `pubspec.yaml`
- Create: `lib/core/storage/session_storage.dart`
- Create: `lib/features/auth/models/session_tokens.dart`
- Create: `lib/features/auth/models/login_response.dart`
- Create: `test/features/auth/auth_repository_test.dart`

- [ ] **Step 1: Write the failing test**

```dart
// test/features/auth/auth_repository_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:kcb_pro_android/features/auth/models/login_response.dart';

void main() {
  test('parses login response with tokens and academic binding info', () {
    final response = LoginResponse.fromJson({
      'access_token': 'access-token',
      'refresh_token': 'refresh-token',
      'token_type': 'bearer',
      'user': {
        'id': 1,
        'school_code': 'hue',
        'academic_username': 'demo_student_id',
      },
    });

    expect(response.tokens.accessToken, 'access-token');
    expect(response.user.academicUsername, 'demo_student_id');
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/auth/auth_repository_test.dart`
Expected: FAIL because the auth models do not exist yet.

- [ ] **Step 3: Write minimal implementation**

```yaml
# pubspec.yaml
dependencies:
  flutter:
    sdk: flutter
  flutter_riverpod: ^2.6.1
  dio: ^5.9.0
  flutter_secure_storage: ^10.0.0
  package_info_plus: ^8.3.0
  path_provider: ^2.1.5
  crypto: ^3.0.6

dev_dependencies:
  flutter_test:
    sdk: flutter
  mocktail: ^1.0.4
```

```dart
// lib/features/auth/models/session_tokens.dart
class SessionTokens {
  const SessionTokens({
    required this.accessToken,
    required this.refreshToken,
    required this.tokenType,
  });

  final String accessToken;
  final String refreshToken;
  final String tokenType;

  factory SessionTokens.fromJson(Map<String, dynamic> json) {
    return SessionTokens(
      accessToken: json['access_token'] as String,
      refreshToken: json['refresh_token'] as String,
      tokenType: json['token_type'] as String,
    );
  }
}
```

```dart
// lib/features/auth/models/login_response.dart
import 'session_tokens.dart';

class LoginUser {
  const LoginUser({
    required this.id,
    required this.schoolCode,
    required this.academicUsername,
  });

  final int id;
  final String schoolCode;
  final String academicUsername;

  factory LoginUser.fromJson(Map<String, dynamic> json) {
    return LoginUser(
      id: json['id'] as int,
      schoolCode: json['school_code'] as String,
      academicUsername: json['academic_username'] as String,
    );
  }
}

class LoginResponse {
  const LoginResponse({
    required this.tokens,
    required this.user,
  });

  final SessionTokens tokens;
  final LoginUser user;

  factory LoginResponse.fromJson(Map<String, dynamic> json) {
    return LoginResponse(
      tokens: SessionTokens.fromJson(json),
      user: LoginUser.fromJson(json['user'] as Map<String, dynamic>),
    );
  }
}
```

```dart
// lib/core/storage/session_storage.dart
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class SessionStorage {
  static const _storage = FlutterSecureStorage();
  static const _accessTokenKey = 'access_token';
  static const _refreshTokenKey = 'refresh_token';

  Future<void> saveTokens(String accessToken, String refreshToken) async {
    await _storage.write(key: _accessTokenKey, value: accessToken);
    await _storage.write(key: _refreshTokenKey, value: refreshToken);
  }

  Future<String?> readAccessToken() => _storage.read(key: _accessTokenKey);
  Future<String?> readRefreshToken() => _storage.read(key: _refreshTokenKey);
  Future<void> clear() => _storage.deleteAll();
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/features/auth/auth_repository_test.dart`
Expected: PASS

### Task 2: Add Riverpod auth state and guarded app shell

**Files:**
- Modify: `lib/main.dart`
- Modify: `lib/app.dart`
- Create: `lib/features/auth/controllers/auth_controller.dart`
- Create: `lib/features/auth/pages/login_page.dart`
- Create: `lib/features/schedule/pages/schedule_page.dart`
- Create: `test/app_boot_test.dart`

- [ ] **Step 1: Write the failing test**

```dart
// test/app_boot_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kcb_pro_android/app.dart';
import 'package:kcb_pro_android/features/auth/controllers/auth_controller.dart';

void main() {
  testWidgets('shows login page when no session exists', (tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: KcbApp(),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('教务系统登录'), findsOneWidget);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/app_boot_test.dart`
Expected: FAIL because the app still boots into the WebView home page.

- [ ] **Step 3: Write minimal implementation**

```dart
// lib/main.dart
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const ProviderScope(child: KcbApp()));
}
```

```dart
// lib/features/auth/controllers/auth_controller.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';

enum AuthStatus { loading, signedOut, signedIn }

class AuthState {
  const AuthState(this.status);

  final AuthStatus status;
}

class AuthController extends StateNotifier<AuthState> {
  AuthController() : super(const AuthState(AuthStatus.signedOut));
}

final authControllerProvider =
    StateNotifierProvider<AuthController, AuthState>((ref) {
  return AuthController();
});
```

```dart
// lib/features/auth/pages/login_page.dart
import 'package:flutter/material.dart';

class LoginPage extends StatelessWidget {
  const LoginPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: Text('教务系统登录'),
      ),
    );
  }
}
```

```dart
// lib/features/schedule/pages/schedule_page.dart
import 'package:flutter/material.dart';

class SchedulePage extends StatelessWidget {
  const SchedulePage({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(child: Text('课表')),
    );
  }
}
```

```dart
// lib/app.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'features/auth/controllers/auth_controller.dart';
import 'features/auth/pages/login_page.dart';
import 'features/schedule/pages/schedule_page.dart';

class KcbApp extends ConsumerWidget {
  const KcbApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authControllerProvider);

    return MaterialApp(
      title: '课表',
      home: switch (authState.status) {
        AuthStatus.signedIn => const SchedulePage(),
        AuthStatus.loading => const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          ),
        AuthStatus.signedOut => const LoginPage(),
      },
    );
  }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/app_boot_test.dart`
Expected: PASS

### Task 3: Build the native login form and call `/api/v1/auth/login`

**Files:**
- Create: `lib/core/network/api_client.dart`
- Create: `lib/features/auth/repositories/auth_repository.dart`
- Modify: `lib/features/auth/controllers/auth_controller.dart`
- Modify: `lib/features/auth/pages/login_page.dart`
- Create: `test/features/auth/login_page_test.dart`

- [ ] **Step 1: Write the failing test**

```dart
// test/features/auth/login_page_test.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kcb_pro_android/features/auth/pages/login_page.dart';
import 'package:flutter/material.dart';

void main() {
  testWidgets('shows validation message when fields are empty', (tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(home: LoginPage()),
      ),
    );

    await tester.tap(find.text('登录'));
    await tester.pump();

    expect(find.text('请输入学号'), findsOneWidget);
    expect(find.text('请输入密码'), findsOneWidget);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/auth/login_page_test.dart`
Expected: FAIL because the login page has no form or button yet.

- [ ] **Step 3: Write minimal implementation**

```dart
// lib/core/network/api_client.dart
import 'package:dio/dio.dart';

class ApiClient {
  ApiClient({Dio? dio})
      : dio = dio ??
            Dio(
              BaseOptions(
                baseUrl: 'http://127.0.0.1:8000/api/v1',
                connectTimeout: const Duration(seconds: 10),
                receiveTimeout: const Duration(seconds: 10),
              ),
            );

  final Dio dio;
}
```

```dart
// lib/features/auth/repositories/auth_repository.dart
import 'package:dio/dio.dart';

import '../../../core/network/api_client.dart';
import '../../../core/storage/session_storage.dart';
import '../models/login_response.dart';

class AuthRepository {
  AuthRepository({
    ApiClient? apiClient,
    SessionStorage? storage,
  })  : _apiClient = apiClient ?? ApiClient(),
        _storage = storage ?? SessionStorage();

  final ApiClient _apiClient;
  final SessionStorage _storage;

  Future<LoginResponse> login({
    required String academicUsername,
    required String password,
  }) async {
    final response = await _apiClient.dio.post<Map<String, dynamic>>(
      '/auth/login',
      data: {
        'school_code': 'hue',
        'academic_username': academicUsername,
        'password': password,
        'device_name': 'flutter-client',
      },
    );

    final result = LoginResponse.fromJson(response.data!);
    await _storage.saveTokens(
      result.tokens.accessToken,
      result.tokens.refreshToken,
    );
    return result;
  }
}
```

```dart
// lib/features/auth/controllers/auth_controller.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../repositories/auth_repository.dart';

enum AuthStatus { loading, signedOut, signedIn }

class AuthState {
  const AuthState(this.status);

  final AuthStatus status;
}

class AuthController extends StateNotifier<AuthState> {
  AuthController(this._repository) : super(const AuthState(AuthStatus.signedOut));

  final AuthRepository _repository;

  Future<void> login({
    required String academicUsername,
    required String password,
  }) async {
    state = const AuthState(AuthStatus.loading);
    await _repository.login(
      academicUsername: academicUsername,
      password: password,
    );
    state = const AuthState(AuthStatus.signedIn);
  }
}

final authControllerProvider =
    StateNotifierProvider<AuthController, AuthState>((ref) {
  return AuthController(AuthRepository());
});
```

```dart
// lib/features/auth/pages/login_page.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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
    return Scaffold(
      appBar: AppBar(title: const Text('教务系统登录')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              TextFormField(
                controller: _usernameController,
                decoration: const InputDecoration(labelText: '学号'),
                validator: (value) => (value == null || value.isEmpty) ? '请输入学号' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _passwordController,
                obscureText: true,
                decoration: const InputDecoration(labelText: '密码'),
                validator: (value) => (value == null || value.isEmpty) ? '请输入密码' : null,
              ),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: () async {
                  if (!(_formKey.currentState?.validate() ?? false)) {
                    return;
                  }

                  await ref.read(authControllerProvider.notifier).login(
                        academicUsername: _usernameController.text,
                        password: _passwordController.text,
                      );
                },
                child: const Text('登录'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/features/auth/login_page_test.dart`
Expected: PASS

### Task 4: Add native schedule models and repository for `/schedule/current`

**Files:**
- Create: `lib/features/schedule/models/course.dart`
- Create: `lib/features/schedule/models/schedule.dart`
- Create: `lib/features/schedule/repositories/schedule_repository.dart`
- Create: `test/features/schedule/schedule_model_test.dart`

- [ ] **Step 1: Write the failing test**

```dart
// test/features/schedule/schedule_model_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:kcb_pro_android/features/schedule/models/schedule.dart';

void main() {
  test('parses stale schedule response with course list', () {
    final schedule = Schedule.fromJson({
      'semester_label': '2026春',
      'generated_at': '2026-04-04T10:00:00Z',
      'is_stale': true,
      'last_synced_at': '2026-04-04T08:00:00Z',
      'courses': [
        {
          'name': '软件测试技术',
          'teacher': '张三',
          'room': 'S4409',
          'weekday': 1,
          'lesson_start': 1,
          'lesson_end': 2,
          'raw_weeks': '1-16(周)',
          'parsed_weeks': [1, 2, 3]
        }
      ],
    });

    expect(schedule.isStale, isTrue);
    expect(schedule.courses.single.room, 'S4409');
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/schedule/schedule_model_test.dart`
Expected: FAIL because the native schedule models do not exist yet.

- [ ] **Step 3: Write minimal implementation**

```dart
// lib/features/schedule/models/course.dart
class Course {
  const Course({
    required this.name,
    required this.teacher,
    required this.room,
    required this.weekday,
    required this.lessonStart,
    required this.lessonEnd,
    required this.rawWeeks,
    required this.parsedWeeks,
  });

  final String name;
  final String teacher;
  final String room;
  final int weekday;
  final int lessonStart;
  final int lessonEnd;
  final String rawWeeks;
  final List<int> parsedWeeks;

  factory Course.fromJson(Map<String, dynamic> json) {
    return Course(
      name: json['name'] as String,
      teacher: json['teacher'] as String,
      room: json['room'] as String,
      weekday: json['weekday'] as int,
      lessonStart: json['lesson_start'] as int,
      lessonEnd: json['lesson_end'] as int,
      rawWeeks: json['raw_weeks'] as String,
      parsedWeeks: List<int>.from(json['parsed_weeks'] as List),
    );
  }
}
```

```dart
// lib/features/schedule/models/schedule.dart
import 'course.dart';

class Schedule {
  const Schedule({
    required this.semesterLabel,
    required this.generatedAt,
    required this.isStale,
    required this.lastSyncedAt,
    required this.courses,
  });

  final String semesterLabel;
  final DateTime generatedAt;
  final bool isStale;
  final DateTime? lastSyncedAt;
  final List<Course> courses;

  factory Schedule.fromJson(Map<String, dynamic> json) {
    return Schedule(
      semesterLabel: json['semester_label'] as String,
      generatedAt: DateTime.parse(json['generated_at'] as String),
      isStale: json['is_stale'] as bool,
      lastSyncedAt: json['last_synced_at'] == null
          ? null
          : DateTime.parse(json['last_synced_at'] as String),
      courses: (json['courses'] as List)
          .map((item) => Course.fromJson(item as Map<String, dynamic>))
          .toList(),
    );
  }
}
```

```dart
// lib/features/schedule/repositories/schedule_repository.dart
import '../../../core/network/api_client.dart';
import '../models/schedule.dart';

class ScheduleRepository {
  ScheduleRepository({ApiClient? apiClient})
      : _apiClient = apiClient ?? ApiClient();

  final ApiClient _apiClient;

  Future<Schedule> fetchCurrentSchedule() async {
    final response = await _apiClient.dio.get<Map<String, dynamic>>(
      '/schedule/current',
    );
    return Schedule.fromJson(response.data!);
  }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/features/schedule/schedule_model_test.dart`
Expected: PASS

### Task 5: Render a native timetable page and stale-state banner

**Files:**
- Create: `lib/features/schedule/controllers/schedule_controller.dart`
- Create: `lib/features/schedule/widgets/schedule_grid.dart`
- Modify: `lib/features/schedule/pages/schedule_page.dart`
- Create: `test/features/schedule/schedule_page_test.dart`

- [ ] **Step 1: Write the failing test**

```dart
// test/features/schedule/schedule_page_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kcb_pro_android/features/schedule/models/course.dart';
import 'package:kcb_pro_android/features/schedule/models/schedule.dart';
import 'package:kcb_pro_android/features/schedule/pages/schedule_page.dart';

void main() {
  testWidgets('shows stale banner and course card content', (tester) async {
    const schedule = Schedule(
      semesterLabel: '2026春',
      generatedAt: DateTime(2026, 4, 4, 10),
      isStale: true,
      lastSyncedAt: DateTime(2026, 4, 4, 8),
      courses: [
        Course(
          name: '软件测试技术',
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

    await tester.pumpWidget(
      MaterialApp(
        home: SchedulePage(schedule: schedule),
      ),
    );

    expect(find.text('课表可能不是最新数据'), findsOneWidget);
    expect(find.text('软件测试技术'), findsOneWidget);
    expect(find.text('S4409'), findsOneWidget);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/schedule/schedule_page_test.dart`
Expected: FAIL because the schedule page does not render native schedule data yet.

- [ ] **Step 3: Write minimal implementation**

```dart
// lib/features/schedule/controllers/schedule_controller.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/schedule.dart';

final scheduleControllerProvider =
    StateProvider<Schedule?>((ref) => null);
```

```dart
// lib/features/schedule/widgets/schedule_grid.dart
import 'package:flutter/material.dart';

import '../models/schedule.dart';

class ScheduleGrid extends StatelessWidget {
  const ScheduleGrid({
    super.key,
    required this.schedule,
  });

  final Schedule schedule;

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      itemCount: schedule.courses.length,
      itemBuilder: (context, index) {
        final course = schedule.courses[index];
        return Card(
          child: ListTile(
            title: Text(course.name),
            subtitle: Text('${course.teacher} · ${course.room}'),
            trailing: Text('周${course.weekday} ${course.lessonStart}-${course.lessonEnd}'),
          ),
        );
      },
    );
  }
}
```

```dart
// lib/features/schedule/pages/schedule_page.dart
import 'package:flutter/material.dart';

import '../models/schedule.dart';
import '../widgets/schedule_grid.dart';

class SchedulePage extends StatelessWidget {
  const SchedulePage({
    super.key,
    this.schedule,
  });

  final Schedule? schedule;

  @override
  Widget build(BuildContext context) {
    final currentSchedule = schedule;

    return Scaffold(
      appBar: AppBar(title: const Text('课表')),
      body: currentSchedule == null
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                if (currentSchedule.isStale)
                  MaterialBanner(
                    content: const Text('课表可能不是最新数据'),
                    actions: const [SizedBox.shrink()],
                  ),
                Expanded(child: ScheduleGrid(schedule: currentSchedule)),
              ],
            ),
    );
  }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/features/schedule/schedule_page_test.dart`
Expected: PASS

### Task 6: Add pull-to-refresh, sync status, and credential rebinding

**Files:**
- Create: `lib/features/settings/pages/settings_page.dart`
- Modify: `lib/features/schedule/controllers/schedule_controller.dart`
- Modify: `lib/features/schedule/pages/schedule_page.dart`
- Create: `test/features/settings/settings_page_test.dart`

- [ ] **Step 1: Write the failing test**

```dart
// test/features/settings/settings_page_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kcb_pro_android/features/settings/pages/settings_page.dart';

void main() {
  testWidgets('renders account fields and rebind action', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: SettingsPage(
          academicUsername: 'demo_student_id',
        ),
      ),
    );

    expect(find.text('demo_student_id'), findsOneWidget);
    expect(find.text('重新绑定教务账号'), findsOneWidget);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/settings/settings_page_test.dart`
Expected: FAIL because the settings page does not exist yet.

- [ ] **Step 3: Write minimal implementation**

```dart
// lib/features/schedule/controllers/schedule_controller.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/schedule.dart';

class ScheduleController extends StateNotifier<AsyncValue<Schedule?>> {
  ScheduleController() : super(const AsyncValue.data(null));

  Future<void> refresh() async {
    state = const AsyncValue.loading();
    state = state.whenData((value) => value);
  }
}
```

```dart
// lib/features/settings/pages/settings_page.dart
import 'package:flutter/material.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({
    super.key,
    required this.academicUsername,
  });

  final String academicUsername;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('设置')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('当前学号：$academicUsername'),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: () {},
              child: const Text('重新绑定教务账号'),
            ),
          ],
        ),
      ),
    );
  }
}
```

```dart
// lib/features/schedule/pages/schedule_page.dart
import 'package:flutter/material.dart';

import '../../settings/pages/settings_page.dart';
import '../models/schedule.dart';
import '../widgets/schedule_grid.dart';

class SchedulePage extends StatelessWidget {
  const SchedulePage({
    super.key,
    this.schedule,
  });

  final Schedule? schedule;

  @override
  Widget build(BuildContext context) {
    final currentSchedule = schedule;

    return Scaffold(
      appBar: AppBar(
        title: const Text('课表'),
        actions: [
          IconButton(
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const SettingsPage(academicUsername: 'demo_student_id'),
                ),
              );
            },
            icon: const Icon(Icons.settings_outlined),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {},
        child: currentSchedule == null
            ? const ListView(
                children: [
                  SizedBox(height: 400, child: Center(child: CircularProgressIndicator())),
                ],
              )
            : ScheduleGrid(schedule: currentSchedule),
      ),
    );
  }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/features/settings/settings_page_test.dart`
Expected: PASS

### Task 7: Repoint Android update checks and remove the WebView entry path

**Files:**
- Modify: `lib/services/update_service.dart`
- Delete: `lib/pages/app_webview_page.dart`
- Modify: `lib/app.dart`
- Create: `test/services/update_service_test.dart`

- [ ] **Step 1: Write the failing test**

```dart
// test/services/update_service_test.dart
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
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/services/update_service_test.dart`
Expected: FAIL because the update service still targets the old WebView-era endpoint.

- [ ] **Step 3: Write minimal implementation**

```dart
// lib/services/update_service.dart
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter/services.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';

import '../models/update_info.dart';

class UpdateServiceException implements Exception {
  UpdateServiceException(this.message);

  final String message;

  @override
  String toString() => message;
}

class UpdateService {
  UpdateService({
    HttpClient? httpClient,
    this.updateMetadataUrl = 'http://127.0.0.1:8000/api/v1/app/update/android',
  }) : _httpClient = httpClient ?? HttpClient();

  static const MethodChannel _channel = MethodChannel(
    'kcb_pro_android/update',
  );

  final HttpClient _httpClient;
  final String updateMetadataUrl;

  Future<UpdateInfo?> getAvailableUpdate() async {
    if (!Platform.isAndroid) {
      return null;
    }

    final updateInfo = await fetchLatestUpdate();
    if (updateInfo == null) {
      return null;
    }

    final packageInfo = await PackageInfo.fromPlatform();
    final localBuildNumber = int.tryParse(packageInfo.buildNumber) ?? 0;
    if (!updateInfo.isNewerThan(localBuildNumber: localBuildNumber)) {
      return null;
    }

    return updateInfo;
  }

  Future<UpdateInfo?> fetchLatestUpdate() async {
    final uri = Uri.parse(updateMetadataUrl);
    final request = await _httpClient.getUrl(uri);
    final response = await request.close();
    if (response.statusCode != HttpStatus.ok) {
      return null;
    }

    final payload = await utf8.decoder.bind(response).join();
    return UpdateInfo.fromJson(jsonDecode(payload) as Map<String, dynamic>);
  }

  Future<void> downloadAndInstall(UpdateInfo updateInfo) async {
    final file = await _downloadApk(updateInfo);
    final digest = await computeFileSha256(file);
    if (digest.toLowerCase() != updateInfo.sha256.toLowerCase()) {
      if (await file.exists()) {
        await file.delete();
      }
      throw UpdateServiceException('APK 校验失败');
    }

    await _channel.invokeMethod<void>('installApk', {'path': file.path});
  }

  Future<String> computeFileSha256(File file) async {
    final digest = await sha256.bind(file.openRead()).first;
    return digest.toString();
  }

  Future<File> _downloadApk(UpdateInfo updateInfo) async {
    final uri = Uri.parse(updateInfo.apkUrl);
    final request = await _httpClient.getUrl(uri);
    final response = await request.close();
    if (response.statusCode != HttpStatus.ok) {
      throw UpdateServiceException('下载更新失败');
    }

    final directory = await getTemporaryDirectory();
    final file = File(
      '${directory.path}/kcb-update-${updateInfo.version}+${updateInfo.buildNumber}.apk',
    );
    final output = file.openWrite();
    await response.forEach(output.add);
    await output.close();
    return file;
  }
}
```

```dart
// lib/app.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'features/auth/controllers/auth_controller.dart';
import 'features/auth/pages/login_page.dart';
import 'features/schedule/pages/schedule_page.dart';

class KcbApp extends ConsumerWidget {
  const KcbApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authControllerProvider);

    return MaterialApp(
      title: '课表',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF0E7490)),
      ),
      home: switch (authState.status) {
        AuthStatus.signedIn => const SchedulePage(),
        AuthStatus.loading => const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          ),
        AuthStatus.signedOut => const LoginPage(),
      },
    );
  }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/services/update_service_test.dart`
Expected: PASS

- [ ] **Step 5: Run the full Flutter verification suite**

Run: `flutter test`
Expected: PASS for auth, schedule, settings, and update tests with no remaining WebView-specific assertions.

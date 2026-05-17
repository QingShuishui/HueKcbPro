import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kcb_pro_android/features/schedule/controllers/schedule_controller.dart';
import 'package:kcb_pro_android/features/schedule/models/course.dart';
import 'package:kcb_pro_android/features/schedule/models/schedule.dart';
import 'package:kcb_pro_android/features/schedule/pages/schedule_page.dart';
import 'package:kcb_pro_android/features/schedule/repositories/schedule_repository.dart';
import 'package:kcb_pro_android/features/schedule/widgets/schedule_grid.dart';

void main() {
  testWidgets('shows week header and refresh time', (tester) async {
    final schedule = Schedule(
      semesterLabel: '2026春',
      generatedAt: DateTime(2026, 4, 4, 10),
      isStale: true,
      lastSyncedAt: DateTime(2026, 4, 4, 8),
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

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: SchedulePage(
            schedule: schedule,
            initialDate: DateTime(2026, 3, 2),
          ),
        ),
      ),
    );

    expect(find.textContaining('课表可能不是最新数据'), findsNothing);
    expect(find.textContaining('课程表获取时间：'), findsOneWidget);
    expect(find.text('软件测试技术'), findsOneWidget);
    expect(find.textContaining('SIT'), findsOneWidget);
    expect(find.textContaining('S4409'), findsOneWidget);
    expect(find.textContaining('学号：'), findsNothing);
    expect(find.text('第1周'), findsWidgets);
  });

  testWidgets('shows retry action when schedule loading fails', (tester) async {
    final container = ProviderContainer(
      overrides: [
        scheduleRepositoryProvider.overrideWithValue(
          _FailingOnceScheduleRepository(),
        ),
      ],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          home: SchedulePage(initialDate: DateTime(2026, 3, 2)),
        ),
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('课表加载失败'), findsOneWidget);
    expect(find.text('重试'), findsOneWidget);
  });

  testWidgets('shows warm icon-only warning action for stale cache', (
    tester,
  ) async {
    final container = ProviderContainer(
      overrides: [
        scheduleRepositoryProvider.overrideWithValue(
          _StaleWarningScheduleRepository(),
        ),
      ],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          home: SchedulePage(initialDate: DateTime(2026, 3, 2)),
        ),
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(
      find.byKey(const ValueKey('schedule-refresh-button')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('schedule-warning-button')),
      findsOneWidget,
    );
    expect(find.text('缓存课表'), findsNothing);

    final surface = tester.widget<Ink>(
      find.byKey(const ValueKey('schedule-warning-surface')),
    );
    final decoration = surface.decoration! as BoxDecoration;
    final gradient = decoration.gradient! as LinearGradient;
    expect(gradient.colors.every((color) => color.alpha < 0xFF), isTrue);
    expect(decoration.shape, BoxShape.circle);
    expect(decoration.boxShadow, isNull);

    final icon = tester.widget<Icon>(
      find.byKey(const ValueKey('schedule-warning-icon')),
    );
    expect(icon.size, 16);
  });

  testWidgets('shows styled warning popup instead of snackbar copy', (
    tester,
  ) async {
    final container = ProviderContainer(
      overrides: [
        scheduleRepositoryProvider.overrideWithValue(
          _StaleWarningScheduleRepository(),
        ),
      ],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          home: SchedulePage(initialDate: DateTime(2026, 3, 2)),
        ),
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    await tester.tap(find.byKey(const ValueKey('schedule-warning-button')));
    await tester.pump();

    expect(find.byType(SnackBar), findsNothing);
    expect(
      find.byKey(const ValueKey('schedule-warning-popup')),
      findsOneWidget,
    );
    expect(find.text('当前显示的是缓存课表，可能不是最新数据'), findsOneWidget);
  });

  testWidgets('shows offline cache warning copy', (tester) async {
    final container = ProviderContainer(
      overrides: [
        scheduleRepositoryProvider.overrideWithValue(
          _OfflineWarningScheduleRepository(),
        ),
      ],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          home: SchedulePage(initialDate: DateTime(2026, 3, 2)),
        ),
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(
      find.byKey(const ValueKey('schedule-refresh-button')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('schedule-warning-button')),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const ValueKey('schedule-warning-button')));
    await tester.pump();

    expect(find.text('当前处于离线状态，正在显示缓存课表'), findsOneWidget);
  });

  testWidgets(
    'keeps refresh action tappable while offline warning is visible',
    (tester) async {
      final container = ProviderContainer(
        overrides: [
          scheduleRepositoryProvider.overrideWithValue(
            _OfflineWarningScheduleRepository(),
          ),
        ],
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            home: SchedulePage(initialDate: DateTime(2026, 3, 2)),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(
        find.byKey(const ValueKey('schedule-warning-button')),
        findsOneWidget,
      );

      await tester.tap(find.byKey(const ValueKey('schedule-refresh-button')));
      await tester.pump();

      expect(find.textContaining('正在同步课表'), findsOneWidget);
      await tester.pump(const Duration(milliseconds: 60));
      await tester.pump();
    },
  );

  testWidgets('switches visible courses when week tile is tapped', (
    tester,
  ) async {
    final schedule = Schedule(
      semesterLabel: '2026春',
      generatedAt: DateTime(2026, 4, 4, 10),
      isStale: false,
      lastSyncedAt: DateTime(2026, 4, 4, 8),
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
          parsedWeeks: [4],
        ),
        Course(
          name: '编译原理',
          code: 'BYYL',
          teacher: '李四',
          room: 'S3301',
          weekday: 2,
          lessonStart: 3,
          lessonEnd: 4,
          rawWeeks: '4-8(周)',
          parsedWeeks: [5],
        ),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: SchedulePage(
            schedule: schedule,
            initialDate: DateTime(2026, 3, 25),
          ),
        ),
      ),
    );

    expect(find.text('软件测试技术'), findsOneWidget);
    expect(find.text('编译原理'), findsNothing);

    await tester.tap(find.byKey(const ValueKey('week-tile-5')));
    await tester.pumpAndSettle();

    expect(find.text('软件测试技术'), findsNothing);
    expect(find.text('编译原理'), findsOneWidget);
  });

  testWidgets('week strip switches to the tapped week schedule', (
    tester,
  ) async {
    final schedule = Schedule(
      semesterLabel: '2026春',
      generatedAt: DateTime(2026, 4, 4, 10),
      isStale: false,
      lastSyncedAt: DateTime(2026, 4, 4, 8),
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
          parsedWeeks: [4],
        ),
        Course(
          name: '编译原理',
          code: 'BYYL',
          teacher: '李四',
          room: 'S3301',
          weekday: 2,
          lessonStart: 3,
          lessonEnd: 4,
          rawWeeks: '4-8(周)',
          parsedWeeks: [5],
        ),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: SchedulePage(
            schedule: schedule,
            initialDate: DateTime(2026, 3, 25),
          ),
        ),
      ),
    );

    expect(find.text('软件测试技术'), findsOneWidget);
    expect(find.text('编译原理'), findsNothing);

    await tester.tap(find.byKey(const ValueKey('week-tile-5')));
    await tester.pumpAndSettle();

    expect(find.text('软件测试技术'), findsNothing);
    expect(find.text('编译原理'), findsOneWidget);
  });

  testWidgets('swiping the schedule area switches weeks', (tester) async {
    final schedule = Schedule(
      semesterLabel: '2026春',
      generatedAt: DateTime(2026, 4, 4, 10),
      isStale: false,
      lastSyncedAt: DateTime(2026, 4, 4, 8),
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
          parsedWeeks: [4],
        ),
        Course(
          name: '编译原理',
          code: 'BYYL',
          teacher: '李四',
          room: 'S3301',
          weekday: 2,
          lessonStart: 3,
          lessonEnd: 4,
          rawWeeks: '4-8(周)',
          parsedWeeks: [5],
        ),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: SchedulePage(
            schedule: schedule,
            initialDate: DateTime(2026, 3, 25),
          ),
        ),
      ),
    );

    expect(find.text('软件测试技术'), findsOneWidget);
    expect(find.text('编译原理'), findsNothing);

    await tester.drag(
      find.byKey(const ValueKey('schedule-swipe-area')),
      const Offset(-300, 0),
    );
    await tester.pumpAndSettle();

    expect(find.text('第5周'), findsWidgets);
  });

  testWidgets('uses a page view for whole-page week swiping', (tester) async {
    final schedule = Schedule(
      semesterLabel: '2026春',
      generatedAt: DateTime(2026, 4, 4, 10),
      isStale: false,
      lastSyncedAt: DateTime(2026, 4, 4, 8),
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
          parsedWeeks: [4],
        ),
        Course(
          name: '编译原理',
          code: 'BYYL',
          teacher: '李四',
          room: 'S3301',
          weekday: 2,
          lessonStart: 3,
          lessonEnd: 4,
          rawWeeks: '4-8(周)',
          parsedWeeks: [5],
        ),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: SchedulePage(
            schedule: schedule,
            initialDate: DateTime(2026, 3, 25),
          ),
        ),
      ),
    );

    expect(find.byType(PageView), findsOneWidget);
  });

  testWidgets('uses measured course content height and caps grid text scale', (
    tester,
  ) async {
    final schedule = Schedule(
      semesterLabel: '2026春',
      generatedAt: DateTime(2026, 4, 4, 10),
      isStale: false,
      lastSyncedAt: DateTime(2026, 4, 4, 8),
      courses: const [
        Course(
          name: '面向对象程序设计面向对象程序设计面向对象程序设计',
          code: 'SIT / BYYL / KCSJ',
          teacher: '张三丰',
          room: 'S4408计算机专业实验室 / S3301',
          weekday: 1,
          lessonStart: 1,
          lessonEnd: 2,
          rawWeeks: '1-16(周)',
          parsedWeeks: [4],
        ),
      ],
    );

    await tester.binding.setSurfaceSize(const Size(360, 780));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      ProviderScope(
        child: MediaQuery(
          data: const MediaQueryData(
            size: Size(360, 780),
            textScaler: TextScaler.linear(1.8),
          ),
          child: MaterialApp(
            home: SchedulePage(
              schedule: schedule,
              initialDate: DateTime(2026, 3, 25),
            ),
          ),
        ),
      ),
    );

    final swipeArea = tester.widget<SizedBox>(
      find.byKey(const ValueKey('schedule-swipe-area')),
    );
    final measuredHeight = ScheduleGrid.estimatedHeight(
      schedule: schedule.filterByWeek(4),
      width: 340,
      textScaler: const TextScaler.linear(1.2),
      textDirection: TextDirection.ltr,
      theme: Theme.of(tester.element(find.byType(SchedulePage))),
    );
    expect(swipeArea.height, measuredHeight + scheduleGridHeightSlack);
    expect(swipeArea.height, lessThanOrEqualTo(780 * 1.5));

    final gridContext = tester.element(
      find.byKey(const ValueKey('schedule-week-4')),
    );
    expect(MediaQuery.textScalerOf(gridContext).scale(1), 1.2);
  });

  testWidgets('does not cap schedule height below measured content', (
    tester,
  ) async {
    final longCourses = List.generate(6, (index) {
      final lessonStart = index * 2 + 1;
      return Course(
        name: '极端超长课程名称测试极端超长课程名称测试极端超长课程名称测试极端超长课程名称测试第$lessonStart节',
        code: 'VERY-LONG-CODE / DEBUG-LONG-CODE / HEIGHT-MEASURE',
        teacher: 'Debug Teacher With Long Name',
        room: 'S4408计算机专业实验室 / BY409智慧教室 / 东区实验楼A305 / 图书馆报告厅',
        weekday: 1,
        lessonStart: lessonStart,
        lessonEnd: lessonStart + 1,
        rawWeeks: '1-16(周)',
        parsedWeeks: const [4],
      );
    });
    final schedule = Schedule(
      semesterLabel: '2026春',
      generatedAt: DateTime(2026, 4, 4, 10),
      isStale: false,
      lastSyncedAt: DateTime(2026, 4, 4, 8),
      courses: longCourses,
    );

    await tester.binding.setSurfaceSize(const Size(428, 997));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      ProviderScope(
        child: MediaQuery(
          data: const MediaQueryData(
            size: Size(428, 997),
            textScaler: TextScaler.linear(1.8),
          ),
          child: MaterialApp(
            home: SchedulePage(
              schedule: schedule,
              initialDate: DateTime(2026, 3, 25),
            ),
          ),
        ),
      ),
    );

    final swipeArea = tester.widget<SizedBox>(
      find.byKey(const ValueKey('schedule-swipe-area')),
    );
    final measuredHeight = ScheduleGrid.estimatedHeight(
      schedule: schedule.filterByWeek(4),
      width: 408,
      textScaler: const TextScaler.linear(1.2),
      textDirection: TextDirection.ltr,
      theme: Theme.of(tester.element(find.byType(SchedulePage))),
    );
    expect(measuredHeight + scheduleGridHeightSlack, greaterThan(997 * 1.5));
    expect(swipeArea.height, measuredHeight + scheduleGridHeightSlack);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'renders week strip as a horizontal list with current week marker',
    (tester) async {
      final schedule = Schedule(
        semesterLabel: '2026春',
        generatedAt: DateTime(2026, 4, 4, 10),
        isStale: false,
        lastSyncedAt: DateTime(2026, 4, 4, 8),
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
            parsedWeeks: [6],
          ),
        ],
      );

      await tester.binding.setSurfaceSize(const Size(360, 780));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: SchedulePage(
              schedule: schedule,
              initialDate: DateTime(2026, 3, 25),
            ),
          ),
        ),
      );

      final horizontalListViews = tester
          .widgetList<ListView>(find.byType(ListView))
          .where((widget) => widget.scrollDirection == Axis.horizontal);

      expect(horizontalListViews.length, 1);
      expect(find.byKey(const ValueKey('week-tile-4')), findsOneWidget);
      expect(find.text('本周'), findsOneWidget);
      expect(find.text('3.23-3.29'), findsOneWidget);
    },
  );

  testWidgets(
    'title follows selected week and return-to-current-week resets selection',
    (tester) async {
      final schedule = Schedule(
        semesterLabel: '2026春',
        generatedAt: DateTime(2026, 4, 4, 10),
        isStale: false,
        lastSyncedAt: DateTime(2026, 4, 4, 8),
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
            parsedWeeks: [4],
          ),
          Course(
            name: '编译原理',
            code: 'BYYL',
            teacher: '李四',
            room: 'S3301',
            weekday: 2,
            lessonStart: 3,
            lessonEnd: 4,
            rawWeeks: '4-8(周)',
            parsedWeeks: [5],
          ),
        ],
      );

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: SchedulePage(
              schedule: schedule,
              initialDate: DateTime(2026, 3, 25),
            ),
          ),
        ),
      );

      expect(find.text('第4周'), findsWidgets);
      expect(find.text('回到本周'), findsNothing);
      expect(find.text('软件测试技术'), findsOneWidget);
      expect(find.text('编译原理'), findsNothing);

      await tester.tap(find.byKey(const ValueKey('week-tile-5')));
      await tester.pumpAndSettle();

      expect(find.text('第5周'), findsWidgets);
      expect(find.text('回到本周'), findsOneWidget);
      expect(find.text('软件测试技术'), findsNothing);
      expect(find.text('编译原理'), findsOneWidget);

      await tester.tap(find.text('回到本周'));
      await tester.pumpAndSettle();

      expect(find.text('第4周'), findsWidgets);
      expect(find.text('回到本周'), findsNothing);
      expect(find.text('软件测试技术'), findsOneWidget);
      expect(find.text('编译原理'), findsNothing);
    },
  );

  testWidgets('shows refresh action and syncing indicator while refreshing', (
    tester,
  ) async {
    final container = ProviderContainer(
      overrides: [
        scheduleRepositoryProvider.overrideWithValue(
          _RefreshingScheduleRepository(),
        ),
      ],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          home: SchedulePage(initialDate: DateTime(2026, 3, 2)),
        ),
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.byIcon(Icons.refresh_rounded), findsOneWidget);

    await tester.tap(find.byIcon(Icons.refresh_rounded));
    await tester.pump();

    expect(find.textContaining('正在同步课表'), findsOneWidget);
    expect(find.text('软件测试技术'), findsOneWidget);
    expect(find.textContaining('课程表获取时间：'), findsOneWidget);
    expect(find.text('课表已更新'), findsNothing);

    await tester.pump(const Duration(milliseconds: 900));
    expect(find.textContaining('正在同步课表'), findsNothing);
    expect(find.text('课表已更新'), findsOneWidget);
    expect(find.text('软件测试技术'), findsNothing);
    expect(find.text('编译原理'), findsOneWidget);
    expect(find.textContaining('课程表获取时间：'), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 1200));
    await tester.pump(const Duration(milliseconds: 50));
  });

  testWidgets(
    'shows background syncing message instead of success when refresh times out',
    (tester) async {
      final repository = _NeverUpdatedPageRefreshRepository();
      final container = ProviderContainer(
        overrides: [
          scheduleControllerProvider.overrideWith(
            (ref) => ScheduleController(
              ref,
              repository,
              refreshPollTimeout: const Duration(milliseconds: 120),
              refreshPollInterval: const Duration(milliseconds: 20),
            ),
          ),
        ],
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            home: SchedulePage(initialDate: DateTime(2026, 3, 2)),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      await tester.tap(find.byKey(const ValueKey('schedule-refresh-button')));
      await tester.pump();
      expect(find.textContaining('正在同步课表'), findsOneWidget);

      await tester.pumpAndSettle();

      expect(find.text('课表已更新'), findsNothing);
      expect(find.text('同步仍在后台进行中'), findsOneWidget);
      expect(repository.refreshCalls, 1);
      await tester.pump(const Duration(milliseconds: 2200));
      await tester.pump(const Duration(milliseconds: 50));
    },
  );

  testWidgets(
    'manual refresh follows the new current week after date changes',
    (tester) async {
      final container = ProviderContainer(
        overrides: [
          scheduleRepositoryProvider.overrideWithValue(
            _WeekRolloverScheduleRepository(),
          ),
        ],
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            home: SchedulePage(initialDate: DateTime(2026, 3, 25)),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('第4周'), findsWidgets);
      expect(find.text('软件测试技术'), findsOneWidget);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            home: SchedulePage(initialDate: DateTime(2026, 3, 30)),
          ),
        ),
      );

      await tester.tap(find.byKey(const ValueKey('schedule-refresh-button')));
      await tester.pump();
      await tester.pumpAndSettle();

      expect(find.text('第5周'), findsWidgets);
      expect(find.text('软件测试技术'), findsNothing);
      expect(find.text('编译原理'), findsOneWidget);
      await tester.pump(const Duration(milliseconds: 1200));
      await tester.pump(const Duration(milliseconds: 100));
    },
  );

  testWidgets('debug date can wait for manual refresh before taking effect', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: SchedulePage(
            schedule: _debugDateSchedule,
            initialDate: DateTime(2026, 3, 25),
            isDebugMode: true,
            debugDateSelector: (context, initialDate) async {
              return DateTime(2026, 3, 30);
            },
          ),
        ),
      ),
    );

    expect(find.text('第4周'), findsWidgets);
    expect(find.text('软件测试技术'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.settings_outlined));
    await tester.pumpAndSettle();
    await tester.tap(find.text('立即刷新生效'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('设置当前日期'));
    await tester.pumpAndSettle();

    expect(find.textContaining('待同步：2026-03-30'), findsOneWidget);

    Navigator.of(tester.element(find.text('Debug 测试'))).pop();
    await tester.pumpAndSettle();

    expect(find.text('第4周'), findsWidgets);
    expect(find.text('软件测试技术'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('schedule-refresh-button')));
    await tester.pump();
    await tester.pumpAndSettle();

    expect(find.text('第5周'), findsWidgets);
    expect(find.text('软件测试技术'), findsNothing);
    expect(find.text('编译原理'), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 1200));
    await tester.pump(const Duration(milliseconds: 100));
  });

  testWidgets('debug refresh duration can simulate timeout feedback', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: SchedulePage(
            schedule: _debugDateSchedule,
            initialDate: DateTime(2026, 3, 25),
            isDebugMode: true,
            debugInitialRefreshDuration: const Duration(seconds: 11),
          ),
        ),
      ),
    );

    await tester.tap(find.byKey(const ValueKey('schedule-refresh-button')));
    await tester.pump();

    expect(find.textContaining('正在同步课表'), findsOneWidget);

    await tester.pump(const Duration(seconds: 10));
    await tester.pump();

    expect(find.text('课表已更新'), findsNothing);
    expect(find.text('同步仍在后台进行中'), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 2200));
    await tester.pump(const Duration(milliseconds: 50));
  });

  testWidgets(
    'auto refreshes schedule when last update is older than one hour',
    (tester) async {
      final container = ProviderContainer(
        overrides: [
          scheduleRepositoryProvider.overrideWithValue(
            _AutoRefreshingScheduleRepository(),
          ),
        ],
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            home: SchedulePage(initialDate: DateTime(2026, 4, 6)),
          ),
        ),
      );

      await tester.pump();
      await tester.pump();

      await tester.pump(const Duration(milliseconds: 900));
      await tester.pump(const Duration(milliseconds: 50));

      expect(find.text('软件测试技术'), findsNothing);
      expect(find.text('编译原理'), findsOneWidget);
      await tester.pump(const Duration(milliseconds: 1200));
      await tester.pump(const Duration(milliseconds: 600));
    },
  );
}

class _FailingOnceScheduleRepository extends ScheduleRepository {
  @override
  Future<Schedule?> readCachedSchedule() async {
    return null;
  }

  @override
  Future<Schedule> fetchCurrentSchedule() async {
    throw Exception('network');
  }
}

class _RefreshingScheduleRepository extends ScheduleRepository {
  int _fetchCallsAfterRefresh = 0;
  bool _refreshRequested = false;

  @override
  Future<Schedule?> readCachedSchedule() async {
    return _initialSchedule;
  }

  @override
  Future<Schedule> fetchCurrentSchedule() async {
    if (!_refreshRequested) {
      return _initialSchedule;
    }

    _fetchCallsAfterRefresh += 1;
    if (_fetchCallsAfterRefresh < 3) {
      return _initialSchedule;
    }
    return _updatedSchedule;
  }

  @override
  Future<void> refreshFromAcademicSystem() async {
    _refreshRequested = true;
    await Future<void>.delayed(const Duration(milliseconds: 50));
  }
}

class _NeverUpdatedPageRefreshRepository extends ScheduleRepository {
  int refreshCalls = 0;

  @override
  Future<Schedule?> readCachedSchedule() async {
    return _initialSchedule;
  }

  @override
  Future<Schedule> fetchCurrentSchedule() async {
    return _initialSchedule;
  }

  @override
  Future<void> refreshFromAcademicSystem() async {
    refreshCalls += 1;
  }
}

class _StaleWarningScheduleRepository extends ScheduleRepository {
  @override
  Future<Schedule?> readCachedSchedule() async {
    return _staleWarningSchedule;
  }

  @override
  Future<Schedule> fetchCurrentSchedule() async {
    return _staleWarningSchedule;
  }
}

class _OfflineWarningScheduleRepository extends ScheduleRepository {
  @override
  Future<Schedule?> readCachedSchedule() async {
    return _initialSchedule;
  }

  @override
  Future<Schedule> fetchCurrentSchedule() async {
    throw _offlineError();
  }

  @override
  Future<void> refreshFromAcademicSystem() async {
    await Future<void>.delayed(const Duration(milliseconds: 50));
    throw _offlineError();
  }
}

class _AutoRefreshingScheduleRepository extends ScheduleRepository {
  bool _refreshRequested = false;
  int _fetchCallsAfterRefresh = 0;

  @override
  Future<Schedule?> readCachedSchedule() async {
    return Schedule(
      semesterLabel: '2026春',
      generatedAt: DateTime.parse('2026-04-04T08:00:00Z'),
      isStale: false,
      lastSyncedAt: DateTime.parse('2026-04-04T08:00:00Z'),
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
          parsedWeeks: [6],
        ),
      ],
    );
  }

  @override
  Future<Schedule> fetchCurrentSchedule() async {
    if (!_refreshRequested) {
      return Schedule(
        semesterLabel: '2026春',
        generatedAt: DateTime.parse('2026-04-04T08:00:00Z'),
        isStale: false,
        lastSyncedAt: DateTime.parse('2026-04-04T08:00:00Z'),
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
            parsedWeeks: [6],
          ),
        ],
      );
    }

    _fetchCallsAfterRefresh += 1;
    if (_fetchCallsAfterRefresh < 3) {
      return Schedule(
        semesterLabel: '2026春',
        generatedAt: DateTime.parse('2026-04-04T08:00:00Z'),
        isStale: false,
        lastSyncedAt: DateTime.parse('2026-04-04T08:00:00Z'),
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

    return Schedule(
      semesterLabel: '2026春',
      generatedAt: DateTime.parse('2026-04-06T10:05:00Z'),
      isStale: false,
      lastSyncedAt: DateTime.parse('2026-04-06T10:05:00Z'),
      courses: const [
        Course(
          name: '编译原理',
          code: 'BYYL',
          teacher: '李四',
          room: 'S3301',
          weekday: 2,
          lessonStart: 3,
          lessonEnd: 4,
          rawWeeks: '1-16(周)',
          parsedWeeks: [6],
        ),
      ],
    );
  }

  @override
  Future<void> refreshFromAcademicSystem() async {
    _refreshRequested = true;
    await Future<void>.delayed(const Duration(milliseconds: 50));
  }
}

class _WeekRolloverScheduleRepository extends ScheduleRepository {
  bool _refreshRequested = false;

  @override
  Future<Schedule?> readCachedSchedule() async {
    return _weekFourSchedule;
  }

  @override
  Future<Schedule> fetchCurrentSchedule() async {
    return _refreshRequested ? _weekFiveSchedule : _weekFourSchedule;
  }

  @override
  Future<void> refreshFromAcademicSystem() async {
    _refreshRequested = true;
    await Future<void>.delayed(const Duration(milliseconds: 50));
  }
}

final _initialSchedule = Schedule(
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

final _updatedSchedule = Schedule(
  semesterLabel: '2026春',
  generatedAt: DateTime.parse('2026-04-04T10:05:00Z'),
  isStale: false,
  lastSyncedAt: DateTime.parse('2026-04-04T10:05:00Z'),
  courses: const [
    Course(
      name: '编译原理',
      code: 'BYYL',
      teacher: '李四',
      room: 'S3301',
      weekday: 2,
      lessonStart: 3,
      lessonEnd: 4,
      rawWeeks: '1-16(周)',
      parsedWeeks: [1, 2, 3],
    ),
  ],
);

final _weekFourSchedule = Schedule(
  semesterLabel: '2026春',
  generatedAt: DateTime(2026, 3, 30),
  isStale: false,
  lastSyncedAt: DateTime(2026, 3, 30),
  courses: const [
    Course(
      name: '软件测试技术',
      code: 'SIT',
      teacher: '张三',
      room: 'S4409',
      weekday: 1,
      lessonStart: 1,
      lessonEnd: 2,
      rawWeeks: '4(周)',
      parsedWeeks: [4],
    ),
  ],
);

final _weekFiveSchedule = Schedule(
  semesterLabel: '2026春',
  generatedAt: DateTime.parse('2026-03-30T10:05:00Z'),
  isStale: false,
  lastSyncedAt: DateTime.parse('2026-03-30T10:05:00Z'),
  courses: const [
    Course(
      name: '编译原理',
      code: 'BYYL',
      teacher: '李四',
      room: 'S3301',
      weekday: 2,
      lessonStart: 3,
      lessonEnd: 4,
      rawWeeks: '5(周)',
      parsedWeeks: [5],
    ),
  ],
);

final _debugDateSchedule = Schedule(
  semesterLabel: 'Debug 日期测试学期',
  generatedAt: DateTime(2026, 3, 25),
  isStale: false,
  lastSyncedAt: DateTime(2026, 3, 25),
  courses: const [
    Course(
      name: '软件测试技术',
      code: 'SIT',
      teacher: '张三',
      room: 'S4409',
      weekday: 1,
      lessonStart: 1,
      lessonEnd: 2,
      rawWeeks: '4(周)',
      parsedWeeks: [4],
    ),
    Course(
      name: '编译原理',
      code: 'BYYL',
      teacher: '李四',
      room: 'S3301',
      weekday: 2,
      lessonStart: 3,
      lessonEnd: 4,
      rawWeeks: '5(周)',
      parsedWeeks: [5],
    ),
  ],
);

final _staleWarningSchedule = Schedule(
  semesterLabel: '2026春',
  generatedAt: DateTime.parse('2026-04-04T10:00:00Z'),
  isStale: true,
  lastSyncedAt: DateTime.parse('2026-04-04T08:00:00Z'),
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

DioException _offlineError() {
  return DioException.connectionError(
    requestOptions: RequestOptions(path: '/schedule/current'),
    reason: 'offline',
    error: const SocketException('network unreachable'),
  );
}

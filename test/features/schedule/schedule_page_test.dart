import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kcb_pro_android/features/schedule/controllers/schedule_controller.dart';
import 'package:kcb_pro_android/features/schedule/models/course.dart';
import 'package:kcb_pro_android/features/schedule/models/schedule.dart';
import 'package:kcb_pro_android/features/schedule/pages/schedule_page.dart';
import 'package:kcb_pro_android/features/schedule/repositories/schedule_repository.dart';

void main() {
  testWidgets('shows refresh time and course card content', (tester) async {
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
    expect(find.text('第1周'), findsOneWidget);
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
    await tester.pump();

    expect(find.text('课表加载失败'), findsOneWidget);
    expect(find.text('重试'), findsOneWidget);
  });

  testWidgets('switches visible courses when date tile is tapped', (
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

    await tester.tap(find.byKey(const ValueKey('date-tile-2026-03-31')));
    await tester.pumpAndSettle();

    expect(find.text('软件测试技术'), findsNothing);
    expect(find.text('编译原理'), findsOneWidget);
  });

  testWidgets(
    'date strip can scroll and switch to the tapped date week schedule',
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

      expect(find.text('软件测试技术'), findsOneWidget);
      expect(find.text('编译原理'), findsNothing);

      await tester.drag(
        find.byKey(const ValueKey('infinite-date-strip')),
        const Offset(-400, 0),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('date-tile-2026-03-31')));
      await tester.pumpAndSettle();

      expect(find.text('软件测试技术'), findsNothing);
      expect(find.text('编译原理'), findsOneWidget);
    },
  );

  testWidgets('renders date strip as a horizontal list with today marker', (
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
          parsedWeeks: [1, 2, 3],
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
    expect(find.byKey(const ValueKey('date-tile-2026-03-25')), findsOneWidget);
    expect(find.text('今天'), findsOneWidget);
  });

  testWidgets('title follows selected week and return-today resets selection', (
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

    expect(find.text('第4周'), findsOneWidget);
    expect(find.text('回到今日'), findsNothing);
    expect(find.text('软件测试技术'), findsOneWidget);
    expect(find.text('编译原理'), findsNothing);

    await tester.tap(find.byKey(const ValueKey('date-tile-2026-03-31')));
    await tester.pumpAndSettle();

    expect(find.text('第5周'), findsOneWidget);
    expect(find.text('回到今日'), findsOneWidget);
    expect(find.text('软件测试技术'), findsNothing);
    expect(find.text('编译原理'), findsOneWidget);

    await tester.tap(find.text('回到今日'));
    await tester.pumpAndSettle();

    expect(find.text('第4周'), findsOneWidget);
    expect(find.text('回到今日'), findsNothing);
    expect(find.text('软件测试技术'), findsOneWidget);
    expect(find.text('编译原理'), findsNothing);
  });

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
    await tester.pump();

    expect(find.byIcon(Icons.refresh_rounded), findsOneWidget);

    await tester.tap(find.byIcon(Icons.refresh_rounded));
    await tester.pump();

    expect(find.textContaining('正在同步课表'), findsOneWidget);
    expect(find.text('软件测试技术'), findsOneWidget);
    expect(find.textContaining('课程表获取时间：'), findsOneWidget);
    expect(find.text('课表已更新'), findsNothing);

    await tester.pump(const Duration(milliseconds: 250));
    expect(find.textContaining('正在同步课表'), findsNothing);
    expect(find.text('课表已更新'), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 1200));
    await tester.pumpAndSettle();
  });
}

class _FailingOnceScheduleRepository extends ScheduleRepository {
  @override
  Future<Schedule> fetchCurrentSchedule() async {
    throw Exception('network');
  }
}

class _RefreshingScheduleRepository extends ScheduleRepository {
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

  @override
  Future<void> refreshFromAcademicSystem() async {
    await Future<void>.delayed(const Duration(milliseconds: 200));
  }
}

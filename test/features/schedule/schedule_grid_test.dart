import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kcb_pro_android/features/schedule/models/course.dart';
import 'package:kcb_pro_android/features/schedule/models/schedule.dart';
import 'package:kcb_pro_android/features/schedule/widgets/schedule_grid.dart';

void main() {
  testWidgets('renders weekday headers, lesson slots, and course card', (
    tester,
  ) async {
    final schedule = Schedule(
      semesterLabel: '2026春',
      generatedAt: DateTime(2026, 4, 5, 9),
      isStale: false,
      lastSyncedAt: DateTime(2026, 4, 5, 9),
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
      MaterialApp(
        home: Scaffold(body: ScheduleGrid(schedule: schedule)),
      ),
    );

    expect(find.text('周一'), findsOneWidget);
    expect(find.text('周日'), findsOneWidget);
    expect(find.text('1-2节'), findsOneWidget);
    expect(find.text('11-12节'), findsOneWidget);
    expect(find.text('软件测试技术'), findsOneWidget);
    expect(find.textContaining('SIT'), findsOneWidget);
    expect(find.textContaining('S4409'), findsOneWidget);
  });

  testWidgets('renders schedule grid without horizontal scrolling', (
    tester,
  ) async {
    final schedule = Schedule(
      semesterLabel: '2026春',
      generatedAt: DateTime(2026, 4, 5, 9),
      isStale: false,
      lastSyncedAt: DateTime(2026, 4, 5, 9),
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
      MaterialApp(
        home: Scaffold(
          body: SizedBox(width: 360, child: ScheduleGrid(schedule: schedule)),
        ),
      ),
    );

    final horizontalScrollViews = tester
        .widgetList<SingleChildScrollView>(find.byType(SingleChildScrollView))
        .where((widget) => widget.scrollDirection == Axis.horizontal);

    expect(horizontalScrollViews, isEmpty);
    expect(find.text('周一'), findsOneWidget);
    expect(find.text('周日'), findsOneWidget);
  });

  testWidgets(
    'renders conflicting courses in the same cell with joined names and rooms',
    (tester) async {
      final schedule = Schedule(
        semesterLabel: '2026春',
        generatedAt: DateTime(2026, 4, 5, 9),
        isStale: false,
        lastSyncedAt: DateTime(2026, 4, 5, 9),
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
        Course(
          name: '编译原理',
          code: 'BYYL',
          teacher: '李四',
            room: 'S3301',
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
          home: Scaffold(body: ScheduleGrid(schedule: schedule)),
        ),
      );

      expect(find.textContaining('软件测试技术 / 编译原理'), findsOneWidget);
      expect(find.textContaining('SIT / BYYL'), findsOneWidget);
      expect(find.textContaining('S4409 / S3301'), findsOneWidget);

      final joinedTitle = tester.widget<Text>(
        find.textContaining('软件测试技术 / 编译原理'),
      );
      final joinedRoom = tester.widget<Text>(
        find.textContaining('S4409 / S3301'),
      );

      expect(joinedTitle.maxLines, isNull);
      expect(joinedRoom.maxLines, isNull);
    },
  );
}

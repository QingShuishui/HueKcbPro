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
        home: Scaffold(
          body: ScheduleGrid(
            schedule: schedule,
            weekStartDate: DateTime(2026, 3, 23),
          ),
        ),
      ),
    );

    expect(find.text('周一'), findsOneWidget);
    expect(find.text('周日'), findsOneWidget);
    expect(find.text('1-2节'), findsOneWidget);
    expect(find.text('上午'), findsWidgets);
    expect(find.text('08:00\n09:40'), findsOneWidget);
    expect(find.text('11-12节'), findsOneWidget);
    expect(find.text('晚上'), findsWidgets);
    expect(find.text('20:20\n21:05'), findsOneWidget);
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
          body: SizedBox(
            width: 360,
            child: ScheduleGrid(
              schedule: schedule,
              weekStartDate: DateTime(2026, 3, 23),
            ),
          ),
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

  testWidgets('allows room addresses to wrap without shrinking font', (
    tester,
  ) async {
    final schedule = Schedule(
      semesterLabel: '2026春',
      generatedAt: DateTime(2026, 4, 5, 9),
      isStale: false,
      lastSyncedAt: DateTime(2026, 4, 5, 9),
      courses: const [
        Course(
          name: 'JavaWeb程序设计',
          code: 'SIT',
          teacher: 'Sam',
          room: 'S4408计算机专业实验室',
          weekday: 1,
          lessonStart: 1,
          lessonEnd: 2,
          rawWeeks: '1-16(周)',
          parsedWeeks: [1, 2, 3],
        ),
      ],
    );

    await tester.binding.setSurfaceSize(const Size(320, 780));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 320,
            child: ScheduleGrid(
              schedule: schedule,
              weekStartDate: DateTime(2026, 3, 23),
            ),
          ),
        ),
      ),
    );

    final roomTextFinder = find.text('S4408计算机专业实验室');
    final roomText = tester.widget<Text>(roomTextFinder);
    expect(roomText.style?.fontSize, 8);
    expect(roomText.maxLines, isNull);
    expect(tester.takeException(), isNull);
  });

  test('estimates taller grid height from longer course content', () {
    final shortSchedule = Schedule(
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
    final longSchedule = Schedule(
      semesterLabel: '2026春',
      generatedAt: DateTime(2026, 4, 5, 9),
      isStale: false,
      lastSyncedAt: DateTime(2026, 4, 5, 9),
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
          parsedWeeks: [1, 2, 3],
        ),
      ],
    );

    final shortHeight = ScheduleGrid.estimatedHeight(
      schedule: shortSchedule,
      width: 360,
      textScaler: TextScaler.noScaling,
      textDirection: TextDirection.ltr,
      theme: ThemeData(),
    );
    final longHeight = ScheduleGrid.estimatedHeight(
      schedule: longSchedule,
      width: 360,
      textScaler: TextScaler.noScaling,
      textDirection: TextDirection.ltr,
      theme: ThemeData(),
    );

    expect(shortHeight, greaterThanOrEqualTo(542));
    expect(longHeight, greaterThan(shortHeight));
  });

  testWidgets('lays out tall measured content without bottom overflow', (
    tester,
  ) async {
    final schedule = Schedule(
      semesterLabel: '2026春',
      generatedAt: DateTime(2026, 4, 5, 9),
      isStale: false,
      lastSyncedAt: DateTime(2026, 4, 5, 9),
      courses: const [
        Course(
          name:
              '超长课程名称测试超长课程名称测试超长课程名称测试超长课程名称测试超长课程名称测试',
          code: 'SIT / BYYL / KCSJ / DEBUG',
          teacher: 'Debug Teacher',
          room:
              'S4408计算机专业实验室 / BY409智慧教室 / 东区实验楼A305 / 图书馆报告厅',
          weekday: 1,
          lessonStart: 1,
          lessonEnd: 2,
          rawWeeks: '1-16(周)',
          parsedWeeks: [1],
        ),
        Course(
          name:
              '另一门超长课程名称测试另一门超长课程名称测试另一门超长课程名称测试另一门超长课程名称测试',
          code: 'LONG-CODE-LONG-CODE-LONG-CODE',
          teacher: 'Very Long Teacher Name',
          room: 'BY999超长地点名称测试教室 / S3301 / S3302',
          weekday: 3,
          lessonStart: 9,
          lessonEnd: 10,
          rawWeeks: '1-16(周)',
          parsedWeeks: [1],
        ),
      ],
    );

    await tester.binding.setSurfaceSize(const Size(428, 1496));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 428,
            height: 1496,
            child: ScheduleGrid(
              schedule: schedule,
              weekStartDate: DateTime(2026, 3, 23),
            ),
          ),
        ),
      ),
    );

    expect(tester.takeException(), isNull);
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
          home: Scaffold(
            body: ScheduleGrid(
              schedule: schedule,
              weekStartDate: DateTime(2026, 3, 23),
            ),
          ),
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

  testWidgets('renders weekday headers with week dates', (tester) async {
    final schedule = Schedule(
      semesterLabel: '2026春',
      generatedAt: DateTime(2026, 4, 5, 9),
      isStale: false,
      lastSyncedAt: DateTime(2026, 4, 5, 9),
      courses: const [],
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ScheduleGrid(
            schedule: schedule,
            weekStartDate: DateTime(2026, 3, 23),
          ),
        ),
      ),
    );

    expect(find.text('周一'), findsOneWidget);
    expect(find.text('3/23'), findsOneWidget);
    expect(find.text('3/29'), findsOneWidget);
  });

  testWidgets('highlights the current weekday header cell', (tester) async {
    final today = DateTime.now();
    final currentWeekStart = DateTime(
      today.year,
      today.month,
      today.day,
    ).subtract(Duration(days: today.weekday - 1));
    final schedule = Schedule(
      semesterLabel: '2026春',
      generatedAt: DateTime(2026, 4, 5, 9),
      isStale: false,
      lastSyncedAt: DateTime(2026, 4, 5, 9),
      courses: const [],
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ScheduleGrid(
            schedule: schedule,
            weekStartDate: currentWeekStart,
          ),
        ),
      ),
    );

    final todayWeekday = DateTime.now().weekday;
    final highlight = tester.widget<DecoratedBox>(
      find.byKey(ValueKey('weekday-highlight-$todayWeekday')),
    );
    final decoration = highlight.decoration as BoxDecoration;

    expect(decoration.color, const Color(0xFFBE185D));
  });

  testWidgets(
    'renders configured short labels for long ideological course names',
    (tester) async {
      final schedule = Schedule(
        semesterLabel: '2026春',
        generatedAt: DateTime(2026, 4, 5, 9),
        isStale: false,
        lastSyncedAt: DateTime(2026, 4, 5, 9),
        courses: const [
          Course(
            name: '毛泽东思想和中国特色社会主义理论体系概论',
            code: '',
            teacher: '张三',
            room: '10301',
            weekday: 1,
            lessonStart: 1,
            lessonEnd: 2,
            rawWeeks: '1-16(周)',
            parsedWeeks: [1, 2, 3],
          ),
          Course(
            name: '习近平新时代中国特色社会主义思想概论',
            code: '',
            teacher: '李四',
            room: 'BY405',
            weekday: 2,
            lessonStart: 1,
            lessonEnd: 2,
            rawWeeks: '1-16(周)',
            parsedWeeks: [1, 2, 3],
          ),
        ],
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ScheduleGrid(
              schedule: schedule,
              weekStartDate: DateTime(2026, 3, 23),
            ),
          ),
        ),
      );

      expect(find.text('毛概'), findsOneWidget);
      expect(find.text('习思想'), findsOneWidget);
      expect(find.text('毛泽东思想和中国特色社会主义理论体系概论'), findsNothing);
      expect(find.text('习近平新时代中国特色社会主义思想概论'), findsNothing);
    },
  );
}

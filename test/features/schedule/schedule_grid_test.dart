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

  testWidgets('shows course code when the row has enough vertical space', (
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

    await tester.binding.setSurfaceSize(const Size(428, 1200));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 428,
            height: 1200,
            child: ScheduleGrid(
              schedule: schedule,
              weekStartDate: DateTime(2026, 3, 23),
            ),
          ),
        ),
      ),
    );

    expect(find.textContaining('SIT'), findsOneWidget);
  });

  testWidgets('shows all course details by default even in compact cells', (
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
          lessonStart: 9,
          lessonEnd: 10,
          rawWeeks: '1,5-8(周)',
          parsedWeeks: [1, 5, 6, 7, 8],
        ),
      ],
    );

    await tester.binding.setSurfaceSize(const Size(360, 640));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 360,
            height: 640,
            child: ScheduleGrid(
              schedule: schedule,
              weekStartDate: DateTime(2026, 3, 23),
            ),
          ),
        ),
      ),
    );

    expect(find.text('JavaWeb程序设计'), findsOneWidget);
    expect(find.text('S4408计算机专业实验室'), findsOneWidget);
    expect(find.text('SIT'), findsOneWidget);
    expect(find.text('Sam'), findsOneWidget);

    final title = tester.widget<Text>(find.text('JavaWeb程序设计'));
    final room = tester.widget<Text>(find.text('S4408计算机专业实验室'));
    final code = tester.widget<Text>(find.text('SIT'));
    final teacher = tester.widget<Text>(find.text('Sam'));

    expect(title.maxLines, isNull);
    expect(title.overflow, isNot(TextOverflow.ellipsis));
    expect(room.maxLines, isNull);
    expect(room.overflow, isNot(TextOverflow.ellipsis));
    expect(code.maxLines, isNull);
    expect(code.overflow, isNot(TextOverflow.ellipsis));
    expect(teacher.maxLines, isNull);
    expect(teacher.overflow, isNot(TextOverflow.ellipsis));

    final renderedTitleSize = tester.getSize(find.text('JavaWeb程序设计'));
    final cellSize = tester.getSize(
      find.byKey(const ValueKey('schedule-cell-9-1')),
    );
    expect(renderedTitleSize.width, greaterThan(cellSize.width / 7));
  });

  testWidgets('summary mode hides lower priority fields when space is tight', (
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
          lessonStart: 9,
          lessonEnd: 10,
          rawWeeks: '1,5-8(周)',
          parsedWeeks: [1, 5, 6, 7, 8],
        ),
      ],
    );

    await tester.binding.setSurfaceSize(const Size(360, 360));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 360,
            height: 360,
            child: ScheduleGrid(
              schedule: schedule,
              weekStartDate: DateTime(2026, 3, 23),
              expandCourseDetails: false,
            ),
          ),
        ),
      ),
    );

    expect(find.text('JavaWeb程序设计'), findsOneWidget);
    expect(find.text('Sam'), findsNothing);
  });

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

  testWidgets('keeps long course content inside bounded large-font grid', (
    tester,
  ) async {
    final schedule = Schedule(
      semesterLabel: '2026春',
      generatedAt: DateTime(2026, 4, 5, 9),
      isStale: false,
      lastSyncedAt: DateTime(2026, 4, 5, 9),
      courses: const [
        Course(
          name: '数据库原理 / 高等数学AII / 综合英语IV',
          code: 'SIT / HUE',
          teacher: '张三',
          room: 'S4408 / 10107 / BY405',
          weekday: 4,
          lessonStart: 5,
          lessonEnd: 6,
          rawWeeks: '1-16(周)',
          parsedWeeks: [1, 2, 3],
        ),
        Course(
          name: 'Java Web程序设计 / 面向对象程序设计',
          code: 'SIT',
          teacher: '李四',
          room: 'S4408 / S4409',
          weekday: 1,
          lessonStart: 7,
          lessonEnd: 8,
          rawWeeks: '1-16(周)',
          parsedWeeks: [1, 2, 3],
        ),
      ],
    );

    await tester.binding.setSurfaceSize(const Size(428, 1492.3));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(
          size: Size(428, 1492.3),
          textScaler: TextScaler.linear(1.8),
        ),
        child: MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 428,
              height: 1492.3,
              child: ScheduleGrid(
                schedule: schedule,
                weekStartDate: DateTime(2026, 5, 4),
              ),
            ),
          ),
        ),
      ),
    );

    expect(tester.takeException(), isNull);
    expect(find.textContaining('数据库原理'), findsOneWidget);
    expect(find.textContaining('Java Web程序设计'), findsOneWidget);
  });

  testWidgets('allocates taller rows to course-heavy lesson slots', (
    tester,
  ) async {
    final schedule = Schedule(
      semesterLabel: '2026春',
      generatedAt: DateTime(2026, 4, 5, 9),
      isStale: false,
      lastSyncedAt: DateTime(2026, 4, 5, 9),
      courses: const [
        Course(
          name: '数据库原理 / 高等数学AII / 综合英语IV',
          code: 'SIT / HUE',
          teacher: '张三',
          room: 'S4408 / 10107 / BY405',
          weekday: 4,
          lessonStart: 5,
          lessonEnd: 6,
          rawWeeks: '1-16(周)',
          parsedWeeks: [1, 2, 3],
        ),
      ],
    );

    await tester.binding.setSurfaceSize(const Size(428, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(
          size: Size(428, 900),
          textScaler: TextScaler.linear(1.4),
        ),
        child: MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 428,
              height: 900,
              child: ScheduleGrid(
                schedule: schedule,
                weekStartDate: DateTime(2026, 5, 4),
              ),
            ),
          ),
        ),
      ),
    );

    expect(tester.takeException(), isNull);

    final emptyCellHeight = tester
        .getSize(find.byKey(const ValueKey('schedule-cell-1-1')))
        .height;
    final heavyCellHeight = tester
        .getSize(find.byKey(const ValueKey('schedule-cell-5-4')))
        .height;

    expect(heavyCellHeight, greaterThan(emptyCellHeight));
  });
}

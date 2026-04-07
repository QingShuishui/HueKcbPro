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
            weekStartDate: DateTime(2026, 4, 6),
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

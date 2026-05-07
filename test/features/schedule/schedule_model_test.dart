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
          'code': 'SIT',
          'teacher': '张三',
          'room': 'S4409',
          'weekday': 1,
          'lesson_start': 1,
          'lesson_end': 2,
          'raw_weeks': '1-16(周)',
          'parsed_weeks': [1, 2, 3],
        },
      ],
    });

    expect(schedule.isStale, isTrue);
    expect(schedule.courses.single.code, 'SIT');
    expect(schedule.courses.single.room, 'S4409');
  });

  test('extracts trailing course code when backend leaves it in name', () {
    final schedule = Schedule.fromJson({
      'semester_label': '2026春',
      'generated_at': '2026-04-04T10:00:00Z',
      'is_stale': false,
      'last_synced_at': '2026-04-04T10:00:00Z',
      'courses': [
        {
          'name': 'JavaWeb程序设计SIT',
          'code': '',
          'teacher': 'Sam',
          'room': 'S4408计算机专业实验室',
          'weekday': 1,
          'lesson_start': 9,
          'lesson_end': 10,
          'raw_weeks': '1,5-8(周)',
          'parsed_weeks': [1, 5, 6, 7, 8],
        },
      ],
    });

    expect(schedule.courses.single.name, 'JavaWeb程序设计');
    expect(schedule.courses.single.code, 'SIT');
  });

  test('derives available weeks and filters courses by selected week', () {
    final schedule = Schedule.fromJson({
      'semester_label': '2026春',
      'generated_at': '2026-04-04T10:00:00Z',
      'is_stale': false,
      'last_synced_at': '2026-04-04T08:00:00Z',
      'courses': [
        {
          'name': '软件测试技术',
          'code': 'SIT',
          'teacher': '张三',
          'room': 'S4409',
          'weekday': 1,
          'lesson_start': 1,
          'lesson_end': 2,
          'raw_weeks': '1-16(周)',
          'parsed_weeks': [1, 2, 3],
        },
        {
          'name': '编译原理',
          'code': 'BYYL',
          'teacher': '李四',
          'room': 'S3301',
          'weekday': 2,
          'lesson_start': 3,
          'lesson_end': 4,
          'raw_weeks': '4-8(周)',
          'parsed_weeks': [4, 5, 6],
        },
      ],
    });

    expect(schedule.availableWeeks, [1, 2, 3, 4, 5, 6]);
    expect(
      schedule.filterByWeek(1).courses.map((course) => course.name).toList(),
      ['软件测试技术'],
    );
    expect(
      schedule.filterByWeek(5).courses.map((course) => course.name).toList(),
      ['编译原理'],
    );
  });
}

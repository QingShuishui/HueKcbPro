import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kcb_pro_android/features/schedule/controllers/schedule_controller.dart';
import 'package:kcb_pro_android/features/schedule/models/course.dart';
import 'package:kcb_pro_android/features/schedule/models/schedule.dart';
import 'package:kcb_pro_android/features/schedule/repositories/schedule_repository.dart';

class FakeScheduleRepository extends ScheduleRepository {
  int refreshCalls = 0;

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
    refreshCalls += 1;
  }
}

class _DelayedRefreshScheduleRepository extends ScheduleRepository {
  int refreshCalls = 0;
  int fetchCallsAfterRefresh = 0;

  @override
  Future<Schedule> fetchCurrentSchedule() async {
    if (refreshCalls == 0) {
      return _oldSchedule;
    }

    fetchCallsAfterRefresh += 1;
    if (fetchCallsAfterRefresh < 3) {
      return _oldSchedule;
    }
    return _newSchedule;
  }

  @override
  Future<void> refreshFromAcademicSystem() async {
    refreshCalls += 1;
  }
}

void main() {
  test('loadSchedule stores schedule in controller state', () async {
    final container = ProviderContainer(
      overrides: [
        scheduleRepositoryProvider.overrideWithValue(FakeScheduleRepository()),
      ],
    );
    addTearDown(container.dispose);

    await container.read(scheduleControllerProvider.notifier).loadSchedule();

    final state = container.read(scheduleControllerProvider);
    expect(state.value?.semesterLabel, '2026春');
    expect(state.value?.courses.single.name, '软件测试技术');
  });

  test('loadSchedule exposes error state when repository throws', () async {
    final container = ProviderContainer(
      overrides: [
        scheduleRepositoryProvider.overrideWithValue(
          _ThrowingScheduleRepository(),
        ),
      ],
    );
    addTearDown(container.dispose);

    await container.read(scheduleControllerProvider.notifier).loadSchedule();

    final state = container.read(scheduleControllerProvider);
    expect(state.hasError, isTrue);
  });

  test(
    'manualRefresh triggers backend refresh then reloads schedule',
    () async {
      final repository = FakeScheduleRepository();
      final container = ProviderContainer(
        overrides: [scheduleRepositoryProvider.overrideWithValue(repository)],
      );
      addTearDown(container.dispose);

      await container.read(scheduleControllerProvider.notifier).manualRefresh();

      final state = container.read(scheduleControllerProvider);
      expect(repository.refreshCalls, 1);
      expect(state.value?.courses.single.name, '软件测试技术');
    },
  );

  test(
    'manualRefresh waits until the refreshed schedule actually changes',
    () async {
      final repository = _DelayedRefreshScheduleRepository();
      final container = ProviderContainer(
        overrides: [scheduleRepositoryProvider.overrideWithValue(repository)],
      );
      addTearDown(container.dispose);

      await container.read(scheduleControllerProvider.notifier).loadSchedule();
      await container.read(scheduleControllerProvider.notifier).manualRefresh();

      final state = container.read(scheduleControllerProvider);
      expect(repository.refreshCalls, 1);
      expect(repository.fetchCallsAfterRefresh, greaterThanOrEqualTo(3));
      expect(state.value?.generatedAt, _newSchedule.generatedAt);
    },
  );
}

class _ThrowingScheduleRepository extends ScheduleRepository {
  @override
  Future<Schedule> fetchCurrentSchedule() async {
    throw Exception('schedule failed');
  }
}

final _oldSchedule = Schedule(
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

final _newSchedule = Schedule(
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

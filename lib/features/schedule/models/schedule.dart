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

  List<int> get availableWeeks {
    final weeks = <int>{
      for (final course in courses) ...course.parsedWeeks,
    }.toList()..sort();
    return weeks;
  }

  Schedule filterByWeek(int? week) {
    if (week == null) {
      return this;
    }

    return Schedule(
      semesterLabel: semesterLabel,
      generatedAt: generatedAt,
      isStale: isStale,
      lastSyncedAt: lastSyncedAt,
      courses: courses
          .where((course) => course.parsedWeeks.contains(week))
          .toList(),
    );
  }

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

  Map<String, dynamic> toJson() {
    return {
      'semester_label': semesterLabel,
      'generated_at': generatedAt.toIso8601String(),
      'is_stale': isStale,
      'last_synced_at': lastSyncedAt?.toIso8601String(),
      'courses': courses.map((course) => course.toJson()).toList(),
    };
  }
}

import 'course.dart';

class Schedule {
  const Schedule({
    required this.semesterLabel,
    required this.generatedAt,
    required this.isStale,
    required this.lastSyncedAt,
    required this.courses,
    this.semesterStartDate,
    this.semesterEndDate,
    this.totalWeeks,
    this.currentWeek,
  });

  final String semesterLabel;
  final DateTime? semesterStartDate;
  final DateTime? semesterEndDate;
  final int? totalWeeks;
  final int? currentWeek;
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
      semesterStartDate: semesterStartDate,
      semesterEndDate: semesterEndDate,
      totalWeeks: totalWeeks,
      currentWeek: currentWeek,
      courses: courses
          .where((course) => course.parsedWeeks.contains(week))
          .toList(),
    );
  }

  factory Schedule.fromJson(Map<String, dynamic> json) {
    return Schedule(
      semesterLabel: json['semester_label'] as String,
      semesterStartDate: json['semester_start_date'] == null
          ? null
          : DateTime.parse(json['semester_start_date'] as String),
      semesterEndDate: json['semester_end_date'] == null
          ? null
          : DateTime.parse(json['semester_end_date'] as String),
      totalWeeks: json['total_weeks'] as int?,
      currentWeek: json['current_week'] as int?,
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
      'semester_start_date': semesterStartDate
          ?.toIso8601String()
          .split('T')
          .first,
      'semester_end_date': semesterEndDate?.toIso8601String().split('T').first,
      'total_weeks': totalWeeks,
      'current_week': currentWeek,
      'generated_at': generatedAt.toIso8601String(),
      'is_stale': isStale,
      'last_synced_at': lastSyncedAt?.toIso8601String(),
      'courses': courses.map((course) => course.toJson()).toList(),
    };
  }
}

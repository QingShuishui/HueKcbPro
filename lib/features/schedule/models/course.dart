class Course {
  const Course({
    required this.name,
    required this.code,
    required this.teacher,
    required this.room,
    required this.weekday,
    required this.lessonStart,
    required this.lessonEnd,
    required this.rawWeeks,
    required this.parsedWeeks,
  });

  final String name;
  final String code;
  final String teacher;
  final String room;
  final int weekday;
  final int lessonStart;
  final int lessonEnd;
  final String rawWeeks;
  final List<int> parsedWeeks;

  factory Course.fromJson(Map<String, dynamic> json) {
    return Course(
      name: json['name'] as String,
      code: (json['code'] as String?) ?? '',
      teacher: json['teacher'] as String,
      room: json['room'] as String,
      weekday: json['weekday'] as int,
      lessonStart: json['lesson_start'] as int,
      lessonEnd: json['lesson_end'] as int,
      rawWeeks: json['raw_weeks'] as String,
      parsedWeeks: List<int>.from(json['parsed_weeks'] as List),
    );
  }
}

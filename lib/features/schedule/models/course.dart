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
      name: _normalizeCourseName(_text(json['name'])),
      code: _text(json['code']),
      // Older backend snapshots may omit teacher or use an alternate key.
      teacher: _firstText(json, const [
        'teacher',
        'teacher_name',
        'teacherName',
        '任课教师',
        '授课教师',
      ]),
      room: _text(json['room']),
      weekday: _number(json['weekday'], fallback: 1),
      lessonStart: _number(json['lesson_start'], fallback: 1),
      lessonEnd: _number(json['lesson_end'], fallback: 1),
      rawWeeks: _text(json['raw_weeks']),
      parsedWeeks:
          (json['parsed_weeks'] as List?)
              ?.map((value) => _number(value, fallback: 0))
              .where((value) => value > 0)
              .toList() ??
          const [],
    );
  }

  static String _text(Object? value) => value?.toString().trim() ?? '';

  static String _firstText(Map<String, dynamic> json, List<String> keys) {
    for (final key in keys) {
      final value = _text(json[key]);
      if (value.isNotEmpty) return value;
    }
    return '';
  }

  static int _number(Object? value, {required int fallback}) {
    if (value is num) return value.toInt();
    return int.tryParse(_text(value)) ?? fallback;
  }

  static String _normalizeCourseName(String value) {
    final match = RegExp(
      r'^(.*?)[(（]+\s*((?:分组|组别)\s*[0-9A-Za-z一二三四五六七八九十]+)\s*[)）]+$',
    ).firstMatch(value);
    if (match == null) return value;
    final group = match.group(2)!.replaceAll(RegExp(r'\s+'), '');
    return '${match.group(1)!.trimRight()}($group)';
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'code': code,
      'teacher': teacher,
      'room': room,
      'weekday': weekday,
      'lesson_start': lessonStart,
      'lesson_end': lessonEnd,
      'raw_weeks': rawWeeks,
      'parsed_weeks': parsedWeeks,
    };
  }
}

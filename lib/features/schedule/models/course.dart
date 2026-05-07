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
    final parsedName = _parseNameAndCode(
      json['name'] as String,
      (json['code'] as String?) ?? '',
    );
    return Course(
      name: parsedName.name,
      code: parsedName.code,
      teacher: json['teacher'] as String,
      room: json['room'] as String,
      weekday: json['weekday'] as int,
      lessonStart: json['lesson_start'] as int,
      lessonEnd: json['lesson_end'] as int,
      rawWeeks: json['raw_weeks'] as String,
      parsedWeeks: List<int>.from(json['parsed_weeks'] as List),
    );
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

({String name, String code}) _parseNameAndCode(String name, String code) {
  final trimmedName = name.trim();
  final trimmedCode = code.trim();
  if (trimmedCode.isNotEmpty) {
    return (name: trimmedName, code: trimmedCode);
  }

  final match = RegExp(r'^(.+?)([A-Z]{2,8})$').firstMatch(trimmedName);
  if (match == null) {
    return (name: trimmedName, code: '');
  }

  final extractedName = match.group(1)!.trim();
  final extractedCode = match.group(2)!.trim();
  if (extractedName.isEmpty) {
    return (name: trimmedName, code: '');
  }

  return (name: extractedName, code: extractedCode);
}

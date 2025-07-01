// Model for study session and subjects
class StudySession {
  final DateTime startTime;
  final int durationMinutes;
  final String? classOrSubject;

  StudySession({
    required this.startTime,
    required this.durationMinutes,
    this.classOrSubject,
  });
}

class StudyClass {
  final String name;
  StudyClass(this.name);
}

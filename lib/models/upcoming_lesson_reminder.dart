import 'dart:convert';

class UpcomingLessonReminder {
  final int lessonId;
  final String subject;
  final String teacher;
  final String auditory;
  final List<String> groups;
  final DateTime startAt;
  final String targetType;
  final String targetValue;

  const UpcomingLessonReminder({
    required this.lessonId,
    required this.subject,
    required this.teacher,
    required this.auditory,
    required this.groups,
    required this.startAt,
    required this.targetType,
    required this.targetValue,
  });

  factory UpcomingLessonReminder.fromMap(Map<String, dynamic> map) {
    final date = (map['date'] as String?) ?? '1970-01-01';
    final startTime = (map['start_time'] as String?) ?? '00:00';

    final dateParts = date.split('-');
    final timeParts = startTime.split(':');

    final year = int.tryParse(dateParts.elementAt(0)) ?? 1970;
    final month = int.tryParse(dateParts.elementAt(1)) ?? 1;
    final day = int.tryParse(dateParts.elementAt(2)) ?? 1;
    final hour = int.tryParse(timeParts.elementAt(0)) ?? 0;
    final minute = int.tryParse(timeParts.elementAt(1)) ?? 0;

    final groupsJson = map['groups_json'] as String?;
    List<String> groups = [];
    if (groupsJson != null && groupsJson.isNotEmpty) {
      final decoded = jsonDecode(groupsJson);
      if (decoded is List) {
        groups = decoded.map((e) => e.toString()).toList();
      }
    }

    return UpcomingLessonReminder(
      lessonId: map['lesson_id'] as int? ?? 0,
      subject: map['subject'] as String? ?? '',
      teacher: map['teacher'] as String? ?? '',
      auditory: map['auditory'] as String? ?? '',
      groups: groups,
      startAt: DateTime(year, month, day, hour, minute),
      targetType: map['target_type'] as String? ?? '',
      targetValue: map['target_value'] as String? ?? '',
    );
  }
}
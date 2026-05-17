import 'dart:convert';

class Lesson {
  final int id;
  final String subject;
  final String teacher;
  final String auditory;
  final String typeLesson;
  final int time;
  final List<String> group;

  Lesson({
    required this.id,
    required this.subject,
    required this.teacher,
    required this.auditory,
    required this.typeLesson,
    required this.time,
    required this.group,
  });

  factory Lesson.fromJson(Map<String, dynamic> json) {
    return Lesson(
      id: json['id'] as int? ?? 0,
      subject: json['subject'] as String? ?? '',
      teacher: json['teacher'] as String? ?? '',
      auditory: json['auditory'] as String? ?? '',
      typeLesson: json['type_lesson'] as String? ?? '',
      time: json['time'] as int? ?? 0,
      group: List<String>.from(json['group'] ?? []),
    );
  }

  factory Lesson.fromMap(Map<String, dynamic> map) {
    final groupsJson = map['groups_json'] as String?;

    List<String> groups = [];
    if (groupsJson != null) {
      final decoded = jsonDecode(groupsJson);
      if (decoded is List) {
        groups = decoded.map((e) => e.toString()).toList();
      }
    }

    return Lesson(
      id: map['lesson_id'] as int? ?? 0,
      subject: map['subject'] as String? ?? '',
      teacher: map['teacher'] as String? ?? '',
      auditory: map['auditory'] as String? ?? '',
      typeLesson: map['lesson_type'] as String? ?? '',
      time: map['slot_id'] as int? ?? 0,
      group: groups,
    );
  }
}
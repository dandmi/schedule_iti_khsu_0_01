import 'lesson.dart';

class ScheduleResponse {
  final int weekday;
  final int weekNumber;
  final List<Lesson> lessons;

  ScheduleResponse({required this.weekday, required this.weekNumber, required this.lessons});

  factory ScheduleResponse.fromJson(Map<String, dynamic> json) {
    final lessons = (json['lessons'] as List?)
        ?.map((e) => Lesson.fromJson(e as Map<String, dynamic>))
        .toList() ??
        [];
    return ScheduleResponse(
      weekday: json['weekday'] as int? ?? 0,
      weekNumber: json['week_number'] as int? ?? 0,
      lessons: lessons,
    );
  }
}
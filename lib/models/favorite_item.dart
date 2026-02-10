import '../utils/schedule_type.dart';

class FavoriteItem {
  final int id;
  final String name;
  final String type; // 'group', 'teacher', 'auditory'

  FavoriteItem({required this.id, required this.name, required this.type});

  factory FavoriteItem.fromMap(Map<String, dynamic> map) {
    return FavoriteItem(
      id: map['id'] as int,
      name: map['name'] as String,
      type: map['type'] as String, // ← должно быть 'group', 'teacher' или 'auditory'
    );
  }

  ScheduleType get scheduleType {
    switch (type) {
      case 'group': return ScheduleType.group;
      case 'teacher': return ScheduleType.teacher;
      case 'auditory': return ScheduleType.auditory;
      default: throw Exception('Неизвестный тип: $type');
    }
  }
}
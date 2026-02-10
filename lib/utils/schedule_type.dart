enum ScheduleType { group, teacher, auditory }

extension ScheduleTypeExt on ScheduleType {
  String get label {
    switch (this) {
      case ScheduleType.group:
        return 'Группа';
      case ScheduleType.teacher:
        return 'Преподаватель';
      case ScheduleType.auditory:
        return 'Аудитория';
    }
  }

  String get iconData {
    switch (this) {
      case ScheduleType.group:
        return '👥';
      case ScheduleType.teacher:
        return '👨‍🏫';
      case ScheduleType.auditory:
        return '🚪';
    }
  }
}
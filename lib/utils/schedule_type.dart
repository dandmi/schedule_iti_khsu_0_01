import 'package:flutter/material.dart';

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

  IconData get icon {
    switch (this) {
      case ScheduleType.group:
        return Icons.group;
      case ScheduleType.teacher:
        return Icons.person;
      case ScheduleType.auditory:
        return Icons.location_on;
    }
  }
}

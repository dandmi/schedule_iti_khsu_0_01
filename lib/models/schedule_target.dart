import '../utils/schedule_type.dart';

class ScheduleTarget {
  final ScheduleType type;
  final String value;

  const ScheduleTarget({
    required this.type,
    required this.value,
  });

  Map<String, String> toPrefsMap() => {
    'type': type.name,
    'value': value,
  };

  static ScheduleType? _parseType(String? raw) {
    switch (raw) {
      case 'group':
        return ScheduleType.group;
      case 'teacher':
        return ScheduleType.teacher;
      case 'auditory':
        return ScheduleType.auditory;
      default:
        return null;
    }
  }

  static ScheduleTarget? fromPrefs({
    required String? typeStr,
    required String? value,
  }) {
    final parsedType = _parseType(typeStr);
    final trimmedValue = value?.trim() ?? '';

    if (parsedType == null || trimmedValue.isEmpty) {
      return null;
    }

    return ScheduleTarget(
      type: parsedType,
      value: trimmedValue,
    );
  }
}
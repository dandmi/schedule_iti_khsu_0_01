import 'package:shared_preferences/shared_preferences.dart';
import '../models/schedule_target.dart';

class CurrentScheduleStorage {
  static const String _typeKey = 'current_schedule_type';
  static const String _valueKey = 'current_schedule_value';

  static const String _legacyTypeKey = 'last_favorite_type';
  static const String _legacyValueKey = 'last_favorite_value';

  static Future<ScheduleTarget?> load() async {
    final prefs = await SharedPreferences.getInstance();

    final current = ScheduleTarget.fromPrefs(
      typeStr: prefs.getString(_typeKey),
      value: prefs.getString(_valueKey),
    );

    if (current != null) {
      return current;
    }

    // Миграция со старой логики, чтобы не потерять последнее выбранное расписание
    final legacy = ScheduleTarget.fromPrefs(
      typeStr: prefs.getString(_legacyTypeKey),
      value: prefs.getString(_legacyValueKey),
    );

    if (legacy != null) {
      await save(legacy);
      return legacy;
    }

    return null;
  }

  static Future<void> save(ScheduleTarget target) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_typeKey, target.type.name);
    await prefs.setString(_valueKey, target.value);
  }

  static Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_typeKey);
    await prefs.remove(_valueKey);
  }
}
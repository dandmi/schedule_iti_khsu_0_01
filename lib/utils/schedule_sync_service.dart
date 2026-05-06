import 'package:flutter/foundation.dart';

import '../api/api_client.dart';
import '../database/database_helper.dart';
import '../utils/current_schedule_storage.dart';
import '../utils/schedule_type.dart';

class ScheduleSyncService {
  ScheduleSyncService._internal();

  static final ScheduleSyncService instance = ScheduleSyncService._internal();

  final ApiClient _api = ApiClient();
  final DatabaseHelper _db = DatabaseHelper();

  Future<bool> syncOnAppStart() async {
    final hasInternet = await _api.hasInternetConnection();
    if (!hasInternet) {
      debugPrint('🌐 Нет интернета: пропускаем стартовую синхронизацию');
      return false;
    }

    final current = await CurrentScheduleStorage.load();
    final favorites = await _db.getFavorites();

    final tasks = <String, ({ScheduleType type, String value, DateTime date})>{};

    void addTask(ScheduleType type, String value, DateTime date) {
      final key =
          '${type.name}|${value.trim()}|${date.year}-${date.month}-${date.day}';
      tasks[key] = (type: type, value: value.trim(), date: date);
    }

    final now = DateTime.now();
    final tomorrow = now.add(const Duration(days: 1));
    final dayAfterTomorrow = now.add(const Duration(days: 2));

    if (current != null) {
      addTask(current.type, current.value, now);
      addTask(current.type, current.value, tomorrow);
      addTask(current.type, current.value, dayAfterTomorrow);
    }

    for (final item in favorites) {
      addTask(item.scheduleType, item.name, tomorrow);
      addTask(item.scheduleType, item.name, dayAfterTomorrow);
    }

    for (final task in tasks.values) {
      await _syncOne(
        type: task.type,
        value: task.value,
        date: task.date,
      );
    }

    return true;
  }

  Future<bool> syncCurrentAndFavoritesFutureDates() async {
    final hasInternet = await _api.hasInternetConnection();
    if (!hasInternet) return false;

    final current = await CurrentScheduleStorage.load();
    final favorites = await _db.getFavorites();

    final tasks = <String, ({ScheduleType type, String value, DateTime date})>{};

    void addTask(ScheduleType type, String value, DateTime date) {
      final key =
          '${type.name}|${value.trim()}|${date.year}-${date.month}-${date.day}';
      tasks[key] = (type: type, value: value.trim(), date: date);
    }

    final tomorrow = DateTime.now().add(const Duration(days: 1));
    final dayAfterTomorrow = DateTime.now().add(const Duration(days: 2));

    if (current != null) {
      addTask(current.type, current.value, tomorrow);
      addTask(current.type, current.value, dayAfterTomorrow);
    }

    for (final item in favorites) {
      addTask(item.scheduleType, item.name, tomorrow);
      addTask(item.scheduleType, item.name, dayAfterTomorrow);
    }

    for (final task in tasks.values) {
      await _syncOne(
        type: task.type,
        value: task.value,
        date: task.date,
      );
    }

    return true;
  }

  Future<void> _syncOne({
    required ScheduleType type,
    required String value,
    required DateTime date,
  }) async {
    try {
      final response = await _api.fetchSchedule(
        type: type,
        value: value,
        date: date,
      );

      final dateStr =
          '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

      await _db.saveSchedule(
        date: dateStr,
        weekday: response.weekday,
        lessons: response.lessons,
        targetType: type.name,
        targetValue: value,
      );
    } catch (e, stack) {
      debugPrint('🌐 Ошибка синхронизации $value: $e\n$stack');
    }
  }
}
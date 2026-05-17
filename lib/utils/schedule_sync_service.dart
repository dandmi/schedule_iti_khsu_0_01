import '../api/api_client.dart';
import '../database/database_helper.dart';
import '../utils/current_schedule_storage.dart';
import '../utils/schedule_type.dart';

class ScheduleSyncService {
  ScheduleSyncService._internal();

  static final ScheduleSyncService instance = ScheduleSyncService._internal();

  static const int preloadDays = 7;

  final ApiClient _api = ApiClient();
  final DatabaseHelper _db = DatabaseHelper();

  Future<bool> syncOnAppStart() {
    return _syncDates(includeCurrentDay: true);
  }

  Future<bool> syncCurrentAndFavoritesFutureDates() {
    return _syncDates(includeCurrentDay: false);
  }

  Future<bool> _syncDates({required bool includeCurrentDay}) async {
    final hasInternet = await _api.hasInternetConnection();
    if (!hasInternet) return false;

    final current = await CurrentScheduleStorage.load();
    final favorites = await _db.getFavorites();

    final tasks = <String, ({ScheduleType type, String value, DateTime date})>{};
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final startOffset = includeCurrentDay ? 0 : 1;
    final endOffset = includeCurrentDay ? preloadDays - 1 : preloadDays;

    void addTask(ScheduleType type, String value, DateTime date) {
      final trimmedValue = value.trim();
      final key = '${type.name}|$trimmedValue|${_dateStr(date)}';

      tasks[key] = (
        type: type,
        value: trimmedValue,
        date: date,
      );
    }

    if (current != null) {
      for (var offset = startOffset; offset <= endOffset; offset++) {
        addTask(
          current.type,
          current.value,
          today.add(Duration(days: offset)),
        );
      }
    }

    for (final item in favorites) {
      for (var offset = 1; offset <= preloadDays; offset++) {
        addTask(
          item.scheduleType,
          item.name,
          today.add(Duration(days: offset)),
        );
      }
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

      await _db.saveSchedule(
        date: _dateStr(date),
        weekday: response.weekday,
        lessons: response.lessons,
        targetType: type.name,
        targetValue: value,
      );
    } catch (_) {}
  }

  String _dateStr(DateTime date) {
    final year = date.year.toString().padLeft(4, '0');
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');

    return '$year-$month-$day';
  }
}

import 'dart:convert';
import 'dart:io';

import 'package:home_widget/home_widget.dart';

import '../api/api_client.dart';
import '../database/database_helper.dart';
import '../models/schedule_response.dart';
import '../utils/current_schedule_storage.dart';
import '../utils/schedule_type.dart';

class ScheduleWidgetService {
  ScheduleWidgetService._internal();

  static final ScheduleWidgetService instance =
  ScheduleWidgetService._internal();

  static const String providerName = 'ScheduleTodayWidgetProvider';
  static const int preloadDays = 7;

  final ApiClient _apiClient = ApiClient();
  final DatabaseHelper _db = DatabaseHelper();

  Future<String> createOrUpdateTodayWidget() async {
    if (!Platform.isAndroid) {
      return 'Виджет пока реализован только для Android';
    }

    final target = await CurrentScheduleStorage.load();
    if (target == null) {
      return 'Сначала выберите текущее расписание';
    }

    final now = DateTime.now();
    final slots = await _db.getTimeSlots();

    final payload = <String, dynamic>{};

    for (int i = 0; i < preloadDays; i++) {
      final date = DateTime(now.year, now.month, now.day + i);

      final schedule = await _loadScheduleForDay(
        targetType: target.type,
        targetValue: target.value,
        date: date,
      );

      payload[_dateStr(date)] = {
        'dateLabel': _formatDate(date),
        'items': _buildWidgetItems(
          schedule: schedule,
          slots: slots,
          scheduleType: target.type,
        ),
      };
    }

    await HomeWidget.saveWidgetData<String>(
      'schedule_widget_target_name',
      target.value,
    );
    await HomeWidget.saveWidgetData<String>(
      'schedule_widget_target_type',
      target.type.name,
    );
    await HomeWidget.saveWidgetData<String>(
      'schedule_widget_payload_json',
      jsonEncode(payload),
    );
    await HomeWidget.saveWidgetData<int>(
      'schedule_widget_generated_at',
      DateTime.now().millisecondsSinceEpoch,
    );

    await HomeWidget.updateWidget(
      name: providerName,
      androidName: providerName,
    );

    final installedWidgets = await HomeWidget.getInstalledWidgets();
    final hasInstalledWidget = installedWidgets.isNotEmpty;
    final pinSupported =
        await HomeWidget.isRequestPinWidgetSupported() ?? false;

    if (!hasInstalledWidget && pinSupported) {
      await HomeWidget.requestPinWidget(
        name: providerName,
        androidName: providerName,
      );
      return 'Виджет подготовлен. Подтвердите добавление на главный экран';
    }

    if (!hasInstalledWidget && !pinSupported) {
      return 'Данные для виджета подготовлены. Добавьте виджет через список виджетов Android';
    }

    return 'Виджет обновлён';
  }

  Future<ScheduleResponse> _loadScheduleForDay({
    required ScheduleType targetType,
    required String targetValue,
    required DateTime date,
  }) async {
    final dateStr = _dateStr(date);

    final hasInternet = await _apiClient.hasInternetConnection();

    if (hasInternet) {
      try {
        final response = await _apiClient.fetchSchedule(
          type: targetType,
          value: targetValue,
          date: date,
        );

        await _db.saveSchedule(
          date: dateStr,
          weekday: response.weekday,
          lessons: response.lessons,
          targetType: targetType.name,
          targetValue: targetValue,
        );

        return response;
      } catch (_) {
        // fallback to cache
      }
    }

    final cached = await _db.getSchedule(
      date: dateStr,
      targetType: targetType.name,
      targetValue: targetValue,
    );

    return ScheduleResponse(
      weekday: date.weekday,
      weekNumber: 0,
      lessons: cached,
    );
  }

  List<Map<String, String>> _buildWidgetItems({
    required ScheduleResponse schedule,
    required Map<int, ({String start, String end})> slots,
    required ScheduleType scheduleType,
  }) {
    if (schedule.lessons.isEmpty) {
      return [
        {
          'title': 'Нет занятий',
          'subtitle': '',
        }
      ];
    }

    final items = <Map<String, String>>[];

    for (final lesson in schedule.lessons) {
      final slot = slots[lesson.time];
      final start = slot?.start ?? '--:--';
      final end = slot?.end ?? '--:--';

      final subtitleParts = <String>[
        lesson.typeLesson,
      ];

      if (scheduleType != ScheduleType.teacher &&
          lesson.teacher.trim().isNotEmpty) {
        subtitleParts.add(lesson.teacher.trim());
      }

      if (scheduleType != ScheduleType.auditory &&
          lesson.auditory.trim().isNotEmpty) {
        subtitleParts.add('Ауд. ${lesson.auditory.trim()}');
      }

      if (scheduleType != ScheduleType.group && lesson.group.isNotEmpty) {
        subtitleParts.add(lesson.group.join(', '));
      }

      items.add({
        'title': '$start–$end  ${lesson.subject}',
        'subtitle': subtitleParts.join(' • '),
      });
    }

    return items;
  }

  String _dateStr(DateTime d) {
    final y = d.year.toString().padLeft(4, '0');
    final m = d.month.toString().padLeft(2, '0');
    final day = d.day.toString().padLeft(2, '0');
    return '$y-$m-$day';
  }

  String _two(int value) => value.toString().padLeft(2, '0');

  String _formatDate(DateTime d) {
    return '${_two(d.day)}.${_two(d.month)}.${d.year}';
  }
}
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:home_widget/home_widget.dart';

import '../api/api_client.dart';
import '../database/database_helper.dart';
import '../models/schedule_response.dart';
import '../models/schedule_target.dart';
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

    await _saveWidgetPreparingData(target);
    await _pinWidgetIfNeeded();
    await _updateWidget();

    unawaited(() async {
      try {
        await _saveWidgetDataForTarget(target);
        await _updateWidget();
      } catch (_) {
        // Виджет уже создан. Ошибка загрузки расписания не должна блокировать UI.
      }
    }());

    return 'Виджет подготовлен. Расписание загружается';
  }

  Future<void> refreshInstalledWidget() async {
    if (!Platform.isAndroid) return;

    final installedWidgets = await HomeWidget.getInstalledWidgets();
    if (installedWidgets.isEmpty) return;

    final target = await CurrentScheduleStorage.load();
    if (target == null) return;

    await _saveWidgetDataForTarget(target);
    await _updateWidget();
  }

  Future<void> _pinWidgetIfNeeded() async {
    final installedWidgets = await HomeWidget.getInstalledWidgets();
    final hasInstalledWidget = installedWidgets.isNotEmpty;
    final pinSupported =
        await HomeWidget.isRequestPinWidgetSupported() ?? false;

    if (!hasInstalledWidget && pinSupported) {
      await HomeWidget.requestPinWidget(
        name: providerName,
        androidName: providerName,
      );
    }
  }

  Future<void> _updateWidget() {
    return HomeWidget.updateWidget(
      name: providerName,
      androidName: providerName,
    );
  }

  Future<void> _saveWidgetPreparingData(ScheduleTarget target) async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final dateKey = _dateStr(today);

    final payload = <String, dynamic>{
      dateKey: {
        'dateLabel': _dateLabel(today),
        'items': [
          {
            'title': 'Расписание загружается',
            'subtitle': 'Данные появятся после обновления',
          },
        ],
      },
    };

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

    await HomeWidget.saveWidgetData<String>(
      'schedule_widget_generated_at',
      DateTime.now().toIso8601String(),
    );
  }

  Future<void> _saveWidgetDataForTarget(ScheduleTarget target) async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final payload = <String, dynamic>{};
    final slots = await _db.getTimeSlots();

    for (var i = 0; i < preloadDays; i++) {
      final date = today.add(Duration(days: i));

      final schedule = await _loadScheduleForDay(
        targetType: target.type,
        targetValue: target.value,
        date: date,
      );

      final dateKey = _dateStr(date);

      payload[dateKey] = {
        'dateLabel': _dateLabel(date),
        'items': _buildWidgetItems(
          schedule: schedule,
          scheduleType: target.type,
          slots: slots,
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

    await HomeWidget.saveWidgetData<String>(
      'schedule_widget_generated_at',
      DateTime.now().toIso8601String(),
    );
  }

  Future<ScheduleResponse?> _loadScheduleForDay({
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
        // Если загрузить расписание из сети не удалось,
        // ниже будет использована локальная копия из БД.
      }
    }

    final hasSnapshot = await _db.hasScheduleSnapshot(
      date: dateStr,
      targetType: targetType.name,
      targetValue: targetValue,
    );

    if (!hasSnapshot) {
      return null;
    }

    final cachedLessons = await _db.getSchedule(
      date: dateStr,
      targetType: targetType.name,
      targetValue: targetValue,
    );

    return ScheduleResponse(
      weekday: date.weekday,
      weekNumber: 0,
      lessons: cachedLessons,
    );
  }

  List<Map<String, String>> _buildWidgetItems({
    required ScheduleResponse? schedule,
    required ScheduleType scheduleType,
    required Map<int, ({String start, String end})> slots,
  }) {
    if (schedule == null) {
      return [
        {
          'title': 'Данные не загружены',
          'subtitle': 'Откройте приложение для обновления',
        },
      ];
    }

    if (schedule.lessons.isEmpty) {
      return [
        {
          'title': 'Нет занятий',
          'subtitle': '',
        },
      ];
    }

    final items = <Map<String, String>>[];

    for (final lesson in schedule.lessons) {
      final slot = slots[lesson.time];
      final start = slot?.start ?? '--:--';
      final end = slot?.end ?? '--:--';

      final subtitleParts = <String>[];

      final typeLesson = lesson.typeLesson.trim();
      if (typeLesson.isNotEmpty) {
        subtitleParts.add(typeLesson);
      }

      final teacher = lesson.teacher.trim();
      if (scheduleType != ScheduleType.teacher && teacher.isNotEmpty) {
        subtitleParts.add(teacher);
      }

      final auditory = lesson.auditory.trim();
      if (scheduleType != ScheduleType.auditory && auditory.isNotEmpty) {
        subtitleParts.add('Ауд. $auditory');
      }

      final groups = lesson.group
          .map((value) => value.trim())
          .where((value) => value.isNotEmpty)
          .toList();

      if (scheduleType != ScheduleType.group && groups.isNotEmpty) {
        subtitleParts.add(groups.join(', '));
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

  String _dateLabel(DateTime d) {
    const weekdays = [
      'Понедельник',
      'Вторник',
      'Среда',
      'Четверг',
      'Пятница',
      'Суббота',
      'Воскресенье',
    ];

    final weekday = weekdays[d.weekday - 1];
    return '$weekday, ${_formatDate(d)}';
  }

  String _two(int value) => value.toString().padLeft(2, '0');

  String _formatDate(DateTime d) {
    return '${_two(d.day)}.${_two(d.month)}.${d.year}';
  }
}
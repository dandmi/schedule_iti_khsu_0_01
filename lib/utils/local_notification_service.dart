import 'dart:io';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

import '../api/api_client.dart';
import '../database/database_helper.dart';
import '../models/lesson.dart';
import '../models/schedule_target.dart';
import 'current_schedule_storage.dart';
import 'notification_settings_storage.dart';

class LocalNotificationService {
  LocalNotificationService._internal();

  static final LocalNotificationService instance =
  LocalNotificationService._internal();

  final FlutterLocalNotificationsPlugin _plugin =
  FlutterLocalNotificationsPlugin();

  static const int notificationPreloadDays = 7;

  final DatabaseHelper _db = DatabaseHelper();
  final ApiClient _api = ApiClient();

  AndroidFlutterLocalNotificationsPlugin? get _androidPlugin =>
      _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();

  bool _initialized = false;

  Future<void> initialize() async {
    if (_initialized) return;

    tz.initializeTimeZones();
    await _configureLocalTimezone();

    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');

    const darwinSettings = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );

    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: darwinSettings,
      macOS: darwinSettings,
    );

    await _plugin.initialize(settings: initSettings);
    _initialized = true;
  }

  Future<void> _configureLocalTimezone() async {
    try {
      final timezoneName = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(timezoneName));
    } catch (_) {}
  }

  Future<void> requestPermissions() async {
    if (!_initialized) {
      await initialize();
    }

    try {
      if (Platform.isAndroid) {
        final android = _androidPlugin;
        await android?.requestNotificationsPermission();

        final canExact = await android?.canScheduleExactNotifications();
        if (canExact != true) {
          try {
            await android?.requestExactAlarmsPermission();
          } catch (_) {}
        }
      }

      if (Platform.isIOS) {
        final ios = _plugin.resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin>();
        await ios?.requestPermissions(
          alert: true,
          badge: true,
          sound: true,
        );
      }

      if (Platform.isMacOS) {
        final mac = _plugin.resolvePlatformSpecificImplementation<
            MacOSFlutterLocalNotificationsPlugin>();
        await mac?.requestPermissions(
          alert: true,
          badge: true,
          sound: true,
        );
      }
    } catch (_) {}
  }

  Future<void> rescheduleAll() async {
    if (!_initialized) {
      await initialize();
    }

    try {
      await _plugin.cancelAll();

      final settings = await NotificationSettingsStorage.load();

      if (settings.noteReminderEnabled) {
        await _scheduleNoteReminders(
          minutesBefore: settings.noteReminderMinutesBefore,
        );
      }

      if (settings.lessonReminderEnabled) {
        await _scheduleLessonReminders(
          minutesBefore: settings.lessonReminderMinutesBefore,
        );
      }

      if (settings.tomorrowSummaryEnabled) {
        await _scheduleTomorrowSummaryReminders(
          hour: settings.tomorrowSummaryHour,
          minute: settings.tomorrowSummaryMinute,
        );
      }
    } catch (_) {}
  }

  Future<AndroidScheduleMode> _resolveAndroidScheduleMode() async {
    if (!Platform.isAndroid) {
      return AndroidScheduleMode.inexactAllowWhileIdle;
    }

    try {
      final canExact = await _androidPlugin?.canScheduleExactNotifications();
      if (canExact == true) {
        return AndroidScheduleMode.exactAllowWhileIdle;
      }
    } catch (_) {}

    return AndroidScheduleMode.inexactAllowWhileIdle;
  }

  Future<void> _scheduleNoteReminders({
    required int minutesBefore,
  }) async {
    final notes = await _db.getNotesWithDueAt();
    final now = tz.TZDateTime.now(tz.local);
    final scheduleMode = await _resolveAndroidScheduleMode();

    for (final note in notes) {
      final dueAtMillis = note.dueAt;
      if (dueAtMillis == null) continue;

      final dueAt = tz.TZDateTime.from(
        DateTime.fromMillisecondsSinceEpoch(dueAtMillis),
        tz.local,
      );

      final notifyAt = dueAt.subtract(Duration(minutes: minutesBefore));
      if (!notifyAt.isAfter(now)) continue;

      final title = (note.title ?? '').trim().isNotEmpty
          ? note.title!.trim()
          : 'Скоро срок по заметке';

      final bodyParts = <String>[];
      final subject = (note.subject ?? '').trim();
      if (subject.isNotEmpty) {
        bodyParts.add('Предмет: $subject');
      }
      bodyParts.add('Срок: ${_formatDateTime(dueAt)}');

      try {
        await _plugin.zonedSchedule(
          id: _stableId('note:${note.id}:${note.dueAt}'),
          title: title,
          body: bodyParts.join(' • '),
          scheduledDate: notifyAt,
          notificationDetails: _noteNotificationDetails(),
          androidScheduleMode: scheduleMode,
          payload: 'note:${note.id ?? 0}',
        );
      } catch (_) {}
    }
  }

  Future<void> _scheduleLessonReminders({
    required int minutesBefore,
  }) async {
    final currentTarget = await CurrentScheduleStorage.load();
    if (currentTarget == null) return;

    final lessons = await _db.getUpcomingLessonsForTarget(
      targetType: currentTarget.type.name,
      targetValue: currentTarget.value,
      fromDate: _dateStr(DateTime.now()),
    );

    final now = tz.TZDateTime.now(tz.local);
    final scheduleMode = await _resolveAndroidScheduleMode();

    for (final lesson in lessons) {
      final startAt = tz.TZDateTime.from(lesson.startAt, tz.local);
      final notifyAt = startAt.subtract(Duration(minutes: minutesBefore));
      if (!notifyAt.isAfter(now)) continue;

      final subtitleParts = <String>[];
      if (lesson.teacher.trim().isNotEmpty) {
        subtitleParts.add(lesson.teacher.trim());
      }
      if (lesson.auditory.trim().isNotEmpty) {
        subtitleParts.add('ауд. ${lesson.auditory.trim()}');
      }
      if (lesson.groups.isNotEmpty) {
        subtitleParts.add(lesson.groups.join(', '));
      }

      final body = subtitleParts.isEmpty
          ? 'Начало в ${_formatTime(startAt)}'
          : '${subtitleParts.join(' • ')} • ${_formatTime(startAt)}';

      try {
        await _plugin.zonedSchedule(
          id: _stableId(
            'lesson:${lesson.targetType}:${lesson.targetValue}:${lesson.lessonId}:${lesson.startAt.millisecondsSinceEpoch}',
          ),
          title: 'Скоро занятие: ${lesson.subject}',
          body: body,
          scheduledDate: notifyAt,
          notificationDetails: _lessonNotificationDetails(),
          androidScheduleMode: scheduleMode,
          payload: 'lesson:${lesson.lessonId}',
        );
      } catch (_) {}
    }
  }

  Future<void> _scheduleTomorrowSummaryReminders({
    required int hour,
    required int minute,
  }) async {
    final currentTarget = await CurrentScheduleStorage.load();
    if (currentTarget == null) return;

    final now = DateTime.now();
    var firstTrigger = DateTime(now.year, now.month, now.day, hour, minute);

    if (!firstTrigger.isAfter(now)) {
      firstTrigger = firstTrigger.add(const Duration(days: 1));
    }

    final scheduleMode = await _resolveAndroidScheduleMode();
    final slots = await _db.getTimeSlots();

    for (var offset = 0; offset < notificationPreloadDays; offset++) {
      final trigger = firstTrigger.add(Duration(days: offset));
      final targetDate = DateTime(
        trigger.year,
        trigger.month,
        trigger.day,
      ).add(const Duration(days: 1));

      final lessons = await _loadLessonsForTargetDate(
        target: currentTarget,
        date: targetDate,
      );

      if (lessons == null) {
        continue;
      }

      final scheduledDate = tz.TZDateTime.from(trigger, tz.local);
      final title = 'Расписание на завтра';
      late final String body;

      if (lessons.isEmpty) {
        body = '${currentTarget.value}: завтра занятий нет';
      } else {
        lessons.sort((a, b) => a.time.compareTo(b.time));
        final firstSlot = slots[lessons.first.time];
        final firstStart = firstSlot?.start ?? '--:--';

        body =
            '${currentTarget.value}: ${lessons.length} ${_pairsWord(lessons.length)}, первая в $firstStart';
      }

      try {
        await _plugin.zonedSchedule(
          id: _stableId(
            'tomorrow-summary:${currentTarget.type.name}:${currentTarget.value}:${_dateStr(trigger)}:${_dateStr(targetDate)}',
          ),
          title: title,
          body: body,
          scheduledDate: scheduledDate,
          notificationDetails: _tomorrowSummaryNotificationDetails(),
          androidScheduleMode: scheduleMode,
          payload: 'tomorrow-summary:${_dateStr(targetDate)}',
        );
      } catch (_) {}
    }
  }

  Future<List<Lesson>?> _loadLessonsForTargetDate({
    required ScheduleTarget target,
    required DateTime date,
  }) async {
    final dateStr = _dateStr(date);

    final hasInternet = await _api.hasInternetConnection();

    if (hasInternet) {
      try {
        final response = await _api.fetchSchedule(
          type: target.type,
          value: target.value,
          date: date,
        );

        await _db.saveSchedule(
          date: dateStr,
          weekday: response.weekday,
          lessons: response.lessons,
          targetType: target.type.name,
          targetValue: target.value,
        );

        return response.lessons;
      } catch (_) {}
    }

    final hasSnapshot = await _db.hasScheduleSnapshot(
      date: dateStr,
      targetType: target.type.name,
      targetValue: target.value,
    );

    if (!hasSnapshot) {
      return null;
    }

    final cached = await _db.getSchedule(
      date: dateStr,
      targetType: target.type.name,
      targetValue: target.value,
    );

    return cached;
  }

  NotificationDetails _lessonNotificationDetails() {
    const android = AndroidNotificationDetails(
      'lesson_reminders_channel',
      'Напоминания о занятиях',
      channelDescription: 'Уведомления перед началом занятий',
      importance: Importance.high,
      priority: Priority.high,
    );

    const darwin = DarwinNotificationDetails();

    return const NotificationDetails(
      android: android,
      iOS: darwin,
      macOS: darwin,
    );
  }

  NotificationDetails _noteNotificationDetails() {
    const android = AndroidNotificationDetails(
      'note_deadlines_channel',
      'Напоминания о сроках',
      channelDescription: 'Уведомления перед сроком в заметках',
      importance: Importance.high,
      priority: Priority.high,
    );

    const darwin = DarwinNotificationDetails();

    return const NotificationDetails(
      android: android,
      iOS: darwin,
      macOS: darwin,
    );
  }

  NotificationDetails _tomorrowSummaryNotificationDetails() {
    const android = AndroidNotificationDetails(
      'tomorrow_schedule_channel',
      'Расписание на завтра',
      channelDescription: 'Уведомления о том, есть ли завтра занятия',
      importance: Importance.high,
      priority: Priority.high,
    );

    const darwin = DarwinNotificationDetails();

    return const NotificationDetails(
      android: android,
      iOS: darwin,
      macOS: darwin,
    );
  }

  String _pairsWord(int count) {
    final mod10 = count % 10;
    final mod100 = count % 100;

    if (mod10 == 1 && mod100 != 11) return 'пара';
    if (mod10 >= 2 && mod10 <= 4 && (mod100 < 12 || mod100 > 14)) {
      return 'пары';
    }
    return 'пар';
  }

  int _stableId(String input) {
    int hash = 2166136261;
    for (final unit in input.codeUnits) {
      hash ^= unit;
      hash = (hash * 16777619) & 0x7fffffff;
    }
    return hash & 0x7fffffff;
  }

  String _dateStr(DateTime date) {
    final y = date.year.toString().padLeft(4, '0');
    final m = date.month.toString().padLeft(2, '0');
    final d = date.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }

  String _two(int value) => value.toString().padLeft(2, '0');

  String _formatTime(DateTime dateTime) {
    return '${_two(dateTime.hour)}:${_two(dateTime.minute)}';
  }

  String _formatDateTime(DateTime dateTime) {
    return '${_two(dateTime.day)}.${_two(dateTime.month)}.${dateTime.year} '
        '${_two(dateTime.hour)}:${_two(dateTime.minute)}';
  }
}
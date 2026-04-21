import 'dart:io';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

import '../database/database_helper.dart';
import 'current_schedule_storage.dart';
import 'notification_settings_storage.dart';

class LocalNotificationService {
  LocalNotificationService._internal();

  static final LocalNotificationService instance =
  LocalNotificationService._internal();

  final FlutterLocalNotificationsPlugin _plugin =
  FlutterLocalNotificationsPlugin();

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

    await _plugin.initialize(
      settings: initSettings,
    );

    _initialized = true;
  }

  Future<void> _configureLocalTimezone() async {
    try {
      final timezoneName = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(timezoneName));
    } catch (_) {
      // Оставляем tz.local по умолчанию
    }
  }

  Future<void> requestPermissions() async {
    if (!_initialized) {
      await initialize();
    }

    if (Platform.isAndroid) {
      final android = _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      await android?.requestNotificationsPermission();
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
  }

  Future<void> rescheduleAll() async {
    if (!_initialized) {
      await initialize();
    }

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
  }

  Future<void> _scheduleNoteReminders({
    required int minutesBefore,
  }) async {
    final db = DatabaseHelper();
    final notes = await db.getNotesWithDueAt();
    final now = tz.TZDateTime.now(tz.local);

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

      await _plugin.zonedSchedule(
        id: _stableId('note:${note.id}:${note.dueAt}'),
        title: title,
        body: bodyParts.join(' • '),
        scheduledDate: notifyAt,
        notificationDetails: _noteNotificationDetails(),
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        payload: 'note:${note.id ?? 0}',
      );
    }
  }

  Future<void> _scheduleLessonReminders({
    required int minutesBefore,
  }) async {
    final currentTarget = await CurrentScheduleStorage.load();
    if (currentTarget == null) return;

    final db = DatabaseHelper();
    final lessons = await db.getUpcomingLessonsForTarget(
      targetType: currentTarget.type.name,
      targetValue: currentTarget.value,
      fromDate: _dateStr(DateTime.now()),
    );

    final now = tz.TZDateTime.now(tz.local);

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

      await _plugin.zonedSchedule(
        id: _stableId(
          'lesson:${lesson.targetType}:${lesson.targetValue}:${lesson.lessonId}:${lesson.startAt.millisecondsSinceEpoch}',
        ),
        title: 'Скоро занятие: ${lesson.subject}',
        body: body,
        scheduledDate: notifyAt,
        notificationDetails: _lessonNotificationDetails(),
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        payload: 'lesson:${lesson.lessonId}',
      );
    }
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
import 'package:shared_preferences/shared_preferences.dart';

class NotificationSettingsData {
  final bool lessonReminderEnabled;
  final int lessonReminderMinutesBefore;

  final bool noteReminderEnabled;
  final int noteReminderMinutesBefore;

  final bool tomorrowSummaryEnabled;
  final int tomorrowSummaryHour;
  final int tomorrowSummaryMinute;

  const NotificationSettingsData({
    required this.lessonReminderEnabled,
    required this.lessonReminderMinutesBefore,
    required this.noteReminderEnabled,
    required this.noteReminderMinutesBefore,
    required this.tomorrowSummaryEnabled,
    required this.tomorrowSummaryHour,
    required this.tomorrowSummaryMinute,
  });

  NotificationSettingsData copyWith({
    bool? lessonReminderEnabled,
    int? lessonReminderMinutesBefore,
    bool? noteReminderEnabled,
    int? noteReminderMinutesBefore,
    bool? tomorrowSummaryEnabled,
    int? tomorrowSummaryHour,
    int? tomorrowSummaryMinute,
  }) {
    return NotificationSettingsData(
      lessonReminderEnabled:
      lessonReminderEnabled ?? this.lessonReminderEnabled,
      lessonReminderMinutesBefore:
      lessonReminderMinutesBefore ?? this.lessonReminderMinutesBefore,
      noteReminderEnabled: noteReminderEnabled ?? this.noteReminderEnabled,
      noteReminderMinutesBefore:
      noteReminderMinutesBefore ?? this.noteReminderMinutesBefore,
      tomorrowSummaryEnabled:
      tomorrowSummaryEnabled ?? this.tomorrowSummaryEnabled,
      tomorrowSummaryHour: tomorrowSummaryHour ?? this.tomorrowSummaryHour,
      tomorrowSummaryMinute:
      tomorrowSummaryMinute ?? this.tomorrowSummaryMinute,
    );
  }
}

class NotificationSettingsStorage {
  static const _lessonEnabledKey = 'lesson_reminder_enabled';
  static const _lessonMinutesKey = 'lesson_reminder_minutes_before';

  static const _noteEnabledKey = 'note_reminder_enabled';
  static const _noteMinutesKey = 'note_reminder_minutes_before';

  static const _tomorrowEnabledKey = 'tomorrow_summary_enabled';
  static const _tomorrowHourKey = 'tomorrow_summary_hour';
  static const _tomorrowMinuteKey = 'tomorrow_summary_minute';

  static const defaults = NotificationSettingsData(
    lessonReminderEnabled: false,
    lessonReminderMinutesBefore: 15,
    noteReminderEnabled: false,
    noteReminderMinutesBefore: 60,
    tomorrowSummaryEnabled: false,
    tomorrowSummaryHour: 20,
    tomorrowSummaryMinute: 0,
  );

  static Future<NotificationSettingsData> load() async {
    final prefs = await SharedPreferences.getInstance();

    return NotificationSettingsData(
      lessonReminderEnabled:
      prefs.getBool(_lessonEnabledKey) ?? defaults.lessonReminderEnabled,
      lessonReminderMinutesBefore:
      prefs.getInt(_lessonMinutesKey) ?? defaults.lessonReminderMinutesBefore,
      noteReminderEnabled:
      prefs.getBool(_noteEnabledKey) ?? defaults.noteReminderEnabled,
      noteReminderMinutesBefore:
      prefs.getInt(_noteMinutesKey) ?? defaults.noteReminderMinutesBefore,
      tomorrowSummaryEnabled:
      prefs.getBool(_tomorrowEnabledKey) ?? defaults.tomorrowSummaryEnabled,
      tomorrowSummaryHour:
      prefs.getInt(_tomorrowHourKey) ?? defaults.tomorrowSummaryHour,
      tomorrowSummaryMinute:
      prefs.getInt(_tomorrowMinuteKey) ?? defaults.tomorrowSummaryMinute,
    );
  }

  static Future<void> save(NotificationSettingsData settings) async {
    final prefs = await SharedPreferences.getInstance();

    await prefs.setBool(_lessonEnabledKey, settings.lessonReminderEnabled);
    await prefs.setInt(
      _lessonMinutesKey,
      settings.lessonReminderMinutesBefore,
    );

    await prefs.setBool(_noteEnabledKey, settings.noteReminderEnabled);
    await prefs.setInt(
      _noteMinutesKey,
      settings.noteReminderMinutesBefore,
    );

    await prefs.setBool(_tomorrowEnabledKey, settings.tomorrowSummaryEnabled);
    await prefs.setInt(_tomorrowHourKey, settings.tomorrowSummaryHour);
    await prefs.setInt(_tomorrowMinuteKey, settings.tomorrowSummaryMinute);
  }
}
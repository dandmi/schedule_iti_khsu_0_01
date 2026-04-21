import 'package:shared_preferences/shared_preferences.dart';

class NotificationSettingsData {
  final bool lessonReminderEnabled;
  final int lessonReminderMinutesBefore;
  final bool noteReminderEnabled;
  final int noteReminderMinutesBefore;

  const NotificationSettingsData({
    required this.lessonReminderEnabled,
    required this.lessonReminderMinutesBefore,
    required this.noteReminderEnabled,
    required this.noteReminderMinutesBefore,
  });

  NotificationSettingsData copyWith({
    bool? lessonReminderEnabled,
    int? lessonReminderMinutesBefore,
    bool? noteReminderEnabled,
    int? noteReminderMinutesBefore,
  }) {
    return NotificationSettingsData(
      lessonReminderEnabled:
      lessonReminderEnabled ?? this.lessonReminderEnabled,
      lessonReminderMinutesBefore:
      lessonReminderMinutesBefore ?? this.lessonReminderMinutesBefore,
      noteReminderEnabled: noteReminderEnabled ?? this.noteReminderEnabled,
      noteReminderMinutesBefore:
      noteReminderMinutesBefore ?? this.noteReminderMinutesBefore,
    );
  }
}

class NotificationSettingsStorage {
  static const _lessonEnabledKey = 'lesson_reminder_enabled';
  static const _lessonMinutesKey = 'lesson_reminder_minutes_before';
  static const _noteEnabledKey = 'note_reminder_enabled';
  static const _noteMinutesKey = 'note_reminder_minutes_before';

  static const defaults = NotificationSettingsData(
    lessonReminderEnabled: false,
    lessonReminderMinutesBefore: 15,
    noteReminderEnabled: false,
    noteReminderMinutesBefore: 60,
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
  }
}
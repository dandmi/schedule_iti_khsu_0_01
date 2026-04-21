import 'package:flutter/material.dart';
import '../utils/notification_settings_storage.dart';

class NotificationSettingsScreen extends StatefulWidget {
  const NotificationSettingsScreen({super.key});

  @override
  State<NotificationSettingsScreen> createState() =>
      _NotificationSettingsScreenState();
}

class _NotificationSettingsScreenState
    extends State<NotificationSettingsScreen> {
  static const List<int> _lessonOptions = [5, 10, 15, 20, 30, 45, 60];
  static const List<int> _noteOptions = [10, 30, 60, 120, 180, 720, 1440];

  bool _isLoading = true;
  bool _lessonReminderEnabled = false;
  int _lessonReminderMinutesBefore = 15;
  bool _noteReminderEnabled = false;
  int _noteReminderMinutesBefore = 60;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final settings = await NotificationSettingsStorage.load();

    if (!mounted) return;

    setState(() {
      _lessonReminderEnabled = settings.lessonReminderEnabled;
      _lessonReminderMinutesBefore = settings.lessonReminderMinutesBefore;
      _noteReminderEnabled = settings.noteReminderEnabled;
      _noteReminderMinutesBefore = settings.noteReminderMinutesBefore;
      _isLoading = false;
    });
  }

  Future<void> _save() async {
    final settings = NotificationSettingsData(
      lessonReminderEnabled: _lessonReminderEnabled,
      lessonReminderMinutesBefore: _lessonReminderMinutesBefore,
      noteReminderEnabled: _noteReminderEnabled,
      noteReminderMinutesBefore: _noteReminderMinutesBefore,
    );

    await NotificationSettingsStorage.save(settings);

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Настройки уведомлений сохранены')),
    );
  }

  String _minutesLabel(int minutes) {
    if (minutes < 60) {
      return '$minutes мин';
    }
    if (minutes % 1440 == 0) {
      final days = minutes ~/ 1440;
      return days == 1 ? '1 день' : '$days дн.';
    }
    if (minutes % 60 == 0) {
      final hours = minutes ~/ 60;
      return hours == 1 ? '1 час' : '$hours ч';
    }
    return '$minutes мин';
  }

  Widget _buildSection({
    required BuildContext context,
    required String title,
    required String subtitle,
    required bool enabled,
    required ValueChanged<bool> onEnabledChanged,
    required int selectedMinutes,
    required ValueChanged<int?> onMinutesChanged,
    required List<int> options,
  }) {
    final scheme = Theme.of(context).colorScheme;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SwitchListTile.adaptive(
            contentPadding: EdgeInsets.zero,
            value: enabled,
            title: Text(
              title,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            subtitle: Text(subtitle),
            onChanged: onEnabledChanged,
          ),
          const SizedBox(height: 8),
          IgnorePointer(
            ignoring: !enabled,
            child: Opacity(
              opacity: enabled ? 1 : 0.55,
              child: DropdownButtonFormField<int>(
                value: selectedMinutes,
                decoration: const InputDecoration(
                  labelText: 'Напомнить заранее',
                  border: OutlineInputBorder(),
                ),
                items: options
                    .map(
                      (minutes) => DropdownMenuItem<int>(
                    value: minutes,
                    child: Text(_minutesLabel(minutes)),
                  ),
                )
                    .toList(),
                onChanged: onMinutesChanged,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Настройки уведомлений'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildSection(
            context: context,
            title: 'До занятия',
            subtitle: 'Напоминать перед началом ближайшего занятия',
            enabled: _lessonReminderEnabled,
            onEnabledChanged: (value) {
              setState(() {
                _lessonReminderEnabled = value;
              });
            },
            selectedMinutes: _lessonReminderMinutesBefore,
            onMinutesChanged: (value) {
              if (value == null) return;
              setState(() {
                _lessonReminderMinutesBefore = value;
              });
            },
            options: _lessonOptions,
          ),
          const SizedBox(height: 16),
          _buildSection(
            context: context,
            title: 'До срока в заметках',
            subtitle: 'Напоминать до наступления срока сдачи в заметках',
            enabled: _noteReminderEnabled,
            onEnabledChanged: (value) {
              setState(() {
                _noteReminderEnabled = value;
              });
            },
            selectedMinutes: _noteReminderMinutesBefore,
            onMinutesChanged: (value) {
              if (value == null) return;
              setState(() {
                _noteReminderMinutesBefore = value;
              });
            },
            options: _noteOptions,
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: _save,
              icon: const Icon(Icons.save),
              label: const Text('Сохранить'),
            ),
          ),
        ],
      ),
    );
  }
}
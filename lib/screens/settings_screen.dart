import 'package:flutter/material.dart';

import 'notification_settings_screen.dart';

class SettingsScreen extends StatelessWidget {
  final ThemeMode themeMode;
  final ValueChanged<ThemeMode> onThemeModeChanged;

  const SettingsScreen({
    super.key,
    required this.themeMode,
    required this.onThemeModeChanged,
  });

  String _themeLabel(ThemeMode mode) {
    switch (mode) {
      case ThemeMode.dark:
        return 'Тёмная';
      case ThemeMode.light:
        return 'Светлая';
      case ThemeMode.system:
        return 'Системная';
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text(
          'Оформление',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: scheme.surfaceContainerHighest.withValues(alpha: 0.45),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: scheme.outlineVariant),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Цветовая схема',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  ChoiceChip(
                    label: const Text('Светлая'),
                    selected: themeMode == ThemeMode.light,
                    onSelected: (_) => onThemeModeChanged(ThemeMode.light),
                  ),
                  ChoiceChip(
                    label: const Text('Тёмная'),
                    selected: themeMode == ThemeMode.dark,
                    onSelected: (_) => onThemeModeChanged(ThemeMode.dark),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'Текущая тема: ${_themeLabel(themeMode)}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        Container(
          width: double.infinity,
          decoration: BoxDecoration(
            color: scheme.surfaceContainerHighest.withValues(alpha: 0.45),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: scheme.outlineVariant),
          ),
          child: ListTile(
            leading: const Icon(Icons.notifications_active_outlined),
            title: const Text('Настройки уведомлений'),
            subtitle: const Text('До занятия и до срока в заметках'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const NotificationSettingsScreen(),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
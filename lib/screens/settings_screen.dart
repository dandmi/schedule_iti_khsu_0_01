import 'package:flutter/material.dart';

import '../utils/schedule_widget_service.dart';
import 'notification_settings_screen.dart';
import '../database/database_helper.dart';
import '../utils/app_refresh_bus.dart';

class SettingsScreen extends StatelessWidget {
  final ThemeMode themeMode;
  final ValueChanged<ThemeMode> onThemeModeChanged;

  const SettingsScreen({
    super.key,
    required this.themeMode,
    required this.onThemeModeChanged,
  });

  Future<void> _createWidget(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);

    try {
      final message =
      await ScheduleWidgetService.instance.createOrUpdateTodayWidget();

      if (!context.mounted) return;

      messenger.showSnackBar(
        SnackBar(content: Text(message)),
      );
    } catch (e) {
      if (!context.mounted) return;

      messenger.showSnackBar(
        SnackBar(content: Text('Не удалось создать виджет: $e')),
      );
    }
  }

  Future<void> _clearDownloadedSchedules(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Очистить загруженные данные?'),
          content: const Text(
            'Будут удалены сохранённые расписания. Избранное, заметки и настройки сохранятся.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Отмена'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Очистить'),
            ),
          ],
        );
      },
    );

    if (confirmed != true || !context.mounted) return;

    await DatabaseHelper().clearDownloadedSchedules();

    AppRefreshBus.markScheduleChanged();

    if (!context.mounted) return;

    messenger.showSnackBar(
      const SnackBar(content: Text('Загруженные расписания удалены')),
    );
  }

  void _showNotImplemented(BuildContext context, String title) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$title пока не реализовано')),
    );
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
        const SizedBox(height: 12),
        Container(
          width: double.infinity,
          decoration: BoxDecoration(
            color: scheme.surfaceContainerHighest.withValues(alpha: 0.45),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: scheme.outlineVariant),
          ),
          child: ListTile(
            leading: const Icon(Icons.widgets_outlined),
            title: const Text('Добавить виджет'),
            subtitle: const Text('Виджет расписания на текущий день'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _createWidget(context),
          ),
        ),
        const SizedBox(height: 12),
        Container(
          width: double.infinity,
          decoration: BoxDecoration(
            color: scheme.surfaceContainerHighest.withValues(alpha: 0.45),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: scheme.outlineVariant),
          ),
          child: ListTile(
            leading: const Icon(Icons.feedback_outlined),
            title: const Text('Обратная связь'),
            subtitle: const Text('Сообщить об ошибке или предложить идею'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _showNotImplemented(context, 'Обратная связь'),
          ),
        ),
        const SizedBox(height: 12),
        Container(
          width: double.infinity,
          decoration: BoxDecoration(
            color: scheme.surfaceContainerHighest.withValues(alpha: 0.45),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: scheme.outlineVariant),
          ),
          child: ListTile(
            leading: const Icon(Icons.share_outlined),
            title: const Text('Порекомендовать друзьям'),
            subtitle: const Text('Поделиться приложением'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _showNotImplemented(context, 'Порекомендовать друзьям'),
          ),
        ),

        const SizedBox(height: 12),
        Container(
          width: double.infinity,
          decoration: BoxDecoration(
            color: scheme.surfaceContainerHighest.withValues(alpha: 0.45),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: scheme.outlineVariant),
          ),
          child: ListTile(
            leading: const Icon(Icons.cleaning_services_outlined),
            title: const Text('Очистить загруженные данные'),
            subtitle: const Text('Удалить сохранённые расписания'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _clearDownloadedSchedules(context),
          ),
        ),
      ],
    );
  }
}
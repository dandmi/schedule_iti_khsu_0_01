import 'dart:async';

import 'package:flutter/material.dart';

import '../database/database_helper.dart';
import '../models/favorite_item.dart';
import '../models/schedule_target.dart';
import '../utils/current_schedule_storage.dart';
import '../utils/local_notification_service.dart';
import '../utils/schedule_type.dart';
import '../utils/schedule_sync_service.dart';
import '../utils/schedule_widget_service.dart';
import '../views/schedule_explorer_view.dart';
import '../utils/app_refresh_bus.dart';
import 'add_favorite_screen.dart';

class ScheduleScreen extends StatefulWidget {
  const ScheduleScreen({super.key});

  @override
  State<ScheduleScreen> createState() => ScheduleScreenState();
}

class ScheduleScreenState extends State<ScheduleScreen> {
  final _db = DatabaseHelper();

  late Future<ScheduleTarget?> _initialTargetFuture;
  final _explorerKey = GlobalKey<ScheduleExplorerViewState>();

  @override
  void initState() {
    super.initState();
    _initialTargetFuture = _loadInitialTarget();
    AppRefreshBus.scheduleVersion.addListener(_onExternalScheduleChanged);
  }

  @override
  void dispose() {
    AppRefreshBus.scheduleVersion.removeListener(_onExternalScheduleChanged);
    super.dispose();
  }

  void _onExternalScheduleChanged() {
    reload();
  }

  Future<ScheduleTarget?> _loadInitialTarget() async {
    return CurrentScheduleStorage.load();
  }

  Future<void> reload() async {
    final target = await CurrentScheduleStorage.load();

    if (!mounted) return;

    final currentSnapshot = await _initialTargetFuture;

    final sameTarget = currentSnapshot?.type == target?.type &&
        currentSnapshot?.value == target?.value;

    if (sameTarget) {
      await _explorerKey.currentState?.refreshExternalData();
      return;
    }

    setState(() {
      _initialTargetFuture = Future.value(target);
    });
  }

  Future<void> _selectTarget(ScheduleTarget target) async {
    await CurrentScheduleStorage.save(target);

    if (!mounted) return;

    setState(() {
      _initialTargetFuture = Future.value(target);
    });

    AppRefreshBus.markScheduleChanged();
    _runCurrentScheduleSideEffects();
  }

  void _runCurrentScheduleSideEffects() {
    unawaited(() async {
      try {
        await ScheduleSyncService.instance.syncCurrentAndFavoritesFutureDates();
        await LocalNotificationService.instance.rescheduleAll();
        await ScheduleWidgetService.instance.refreshInstalledWidget();
      } catch (_) {
        // Выбор расписания не должен блокироваться из-за фоновой синхронизации.
      }
    }());
  }

  Future<void> _openAddFavorite() async {
    final target = await Navigator.of(context).push<ScheduleTarget>(
      MaterialPageRoute(
        builder: (_) => const AddFavoriteScreen(),
      ),
    );

    if (!mounted || target == null) return;

    await _selectTarget(target);
  }

  IconData _iconFor(ScheduleType type) {
    switch (type) {
      case ScheduleType.group:
        return Icons.groups_rounded;
      case ScheduleType.teacher:
        return Icons.person_rounded;
      case ScheduleType.auditory:
        return Icons.meeting_room_rounded;
    }
  }

  String _labelFor(ScheduleType type) {
    switch (type) {
      case ScheduleType.group:
        return 'Группа';
      case ScheduleType.teacher:
        return 'Преподаватель';
      case ScheduleType.auditory:
        return 'Аудитория';
    }
  }

  Widget _buildEmptyState(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return FutureBuilder<List<FavoriteItem>>(
      future: _db.getFavorites(),
      builder: (context, favoritesSnapshot) {
        final favorites = favoritesSnapshot.data ?? [];

        return Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: Card(
                elevation: 0,
                color: scheme.surfaceContainerHighest,
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Icon(
                        Icons.schedule_rounded,
                        size: 48,
                        color: scheme.primary,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Расписание не выбрано',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 8),

                      const SizedBox(height: 20),
                      if (favoritesSnapshot.connectionState !=
                          ConnectionState.done)
                        const Center(child: CircularProgressIndicator())
                      else if (favorites.isNotEmpty) ...[
                        Text(
                          'Избранные расписания',
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 8),
                        ...favorites.map(
                              (item) => Card(
                            margin: const EdgeInsets.only(bottom: 8),
                            child: ListTile(
                              leading: Icon(_iconFor(item.scheduleType)),
                              title: Text(item.name),
                              subtitle: Text(_labelFor(item.scheduleType)),
                              onTap: () => _selectTarget(
                                ScheduleTarget(
                                  type: item.scheduleType,
                                  value: item.name,
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                      ],
                      FilledButton.icon(
                        onPressed: _openAddFavorite,
                        icon: const Icon(Icons.add_rounded),
                        label: const Text('Добавить расписание'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<ScheduleTarget?>(
      future: _initialTargetFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(
            child: Text('Ошибка загрузки настроек: ${snapshot.error}'),
          );
        }

        final target = snapshot.data;

        if (target == null) {
          return _buildEmptyState(context);
        }

        return ScheduleExplorerView(
          key: _explorerKey,
          initialType: target.type,
          initialValue: target.value,
        );
      },
    );
  }
}
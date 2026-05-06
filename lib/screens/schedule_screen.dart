import 'package:flutter/material.dart';

import '../models/schedule_target.dart';
import '../utils/current_schedule_storage.dart';
import '../views/schedule_explorer_view.dart';
import '../utils/app_refresh_bus.dart';

class ScheduleScreen extends StatefulWidget {
  const ScheduleScreen({super.key});

  @override
  State<ScheduleScreen> createState() => ScheduleScreenState();
}

class ScheduleScreenState extends State<ScheduleScreen> {
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
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                'Выберите расписание через выпадающий список или добавьте его в избранное',
                textAlign: TextAlign.center,
              ),
            ),
          );
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
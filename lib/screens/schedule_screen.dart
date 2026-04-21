import 'package:flutter/material.dart';
import '../models/schedule_target.dart';
import '../utils/current_schedule_storage.dart';
import '../views/schedule_explorer_view.dart';

class ScheduleScreen extends StatefulWidget {
  const ScheduleScreen({super.key});

  @override
  State<ScheduleScreen> createState() => ScheduleScreenState();
}

class ScheduleScreenState extends State<ScheduleScreen> {
  late Future<ScheduleTarget?> _initialTargetFuture;

  @override
  void initState() {
    super.initState();
    _initialTargetFuture = _loadInitialTarget();
  }

  Future<ScheduleTarget?> _loadInitialTarget() async {
    final target = await CurrentScheduleStorage.load();
    debugPrint(
      '📂 Current schedule: '
          'type=${target?.type.name}, value=${target?.value}',
    );
    return target;
  }

  Future<void> reload() async {
    setState(() {
      _initialTargetFuture = _loadInitialTarget();
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

        if (target != null) {
          return ScheduleExplorerView(
            initialType: target.type,
            initialValue: target.value,
          );
        }

        return const Center(
          child: Padding(
            padding: EdgeInsets.all(16),
            child: Text(
              'Выберите расписание в "Доп. возможностях"',
              textAlign: TextAlign.center,
            ),
          ),
        );
      },
    );
  }
}
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../utils/schedule_type.dart';
import '../views/schedule_explorer_view.dart';

class ScheduleScreen extends StatefulWidget {
  const ScheduleScreen({super.key});

  @override
  State<ScheduleScreen> createState() => ScheduleScreenState();
}

class ScheduleScreenState extends State<ScheduleScreen> {
  late Future<Map<String, dynamic>?> _initialArgsFuture;

  @override
  void initState() {
    super.initState();
    _initialArgsFuture = _loadInitialArgs();
  }

  Future<Map<String, dynamic>?> _loadInitialArgs() async {
    final prefs = await SharedPreferences.getInstance();

    final typeStr = prefs.getString('last_favorite_type');
    final value = prefs.getString('last_favorite_value');

    debugPrint('📂 SharedPreferences: type=$typeStr, value=$value');

    if (typeStr == null || value == null) return null;

    final type = switch (typeStr) {
      'group' => ScheduleType.group,
      'teacher' => ScheduleType.teacher,
      'auditory' => ScheduleType.auditory,
      _ => null,
    };

    if (type == null) return null;

    return {
      'type': type,
      'value': value,
      'isFavorite': true,
    };
  }

  Future<void> reload() async {
    setState(() {
      _initialArgsFuture = _loadInitialArgs();
    });
  }


  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, dynamic>?>(
      future: _initialArgsFuture,
      builder: (context, snapshot) {
        // 1) загрузка
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }

        // 2) ошибка
        if (snapshot.hasError) {
          return Center(
            child: Text('Ошибка загрузки настроек: ${snapshot.error}'),
          );
        }

        // 3) данные есть
        final args = snapshot.data;
        if (args != null) {
          return ScheduleExplorerView(
            initialType: args['type'] as ScheduleType,
            initialValue: args['value'] as String,
            isFavorite: args['isFavorite'] as bool,
          );
        }

        // 4) нет сохранённого избранного
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

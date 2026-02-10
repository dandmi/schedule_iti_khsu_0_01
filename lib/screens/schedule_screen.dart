import 'package:flutter/material.dart';
import 'package:schedule_iti_khsu_0_01/views/schedule_explorer_view.dart';
import 'package:schedule_iti_khsu_0_01/widgets/main_layout.dart';
import '../utils/schedule_type.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ScheduleScreen extends StatefulWidget {
  const ScheduleScreen({super.key});

  @override
  State<ScheduleScreen> createState() => _ScheduleScreenState();
}

class _ScheduleScreenState extends State<ScheduleScreen> {
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

    debugPrint('📂 Прочитано из SharedPreferences: type=$typeStr, value=$value');

    if (typeStr != null && value != null) {
      ScheduleType? type;
      if (typeStr == 'group') type = ScheduleType.group;
      else if (typeStr == 'teacher') type = ScheduleType.teacher;
      else if (typeStr == 'auditory') type = ScheduleType.auditory;

      if (type != null) {
        debugPrint('✅ Возвращаем сохранённое избранное');
        return {
          'type': type,
          'value': value,
          'isFavorite': true,
        };
      }
    }

    debugPrint('❌ Нет сохранённого избранного');
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, dynamic>?>(
      future: _initialArgsFuture,
      builder: (context, snapshot) {
        if (snapshot.hasData && snapshot.data != null) {
          final args = snapshot.data!;
          return MainLayout(
            body: ScheduleExplorerView(
              initialType: args['type'] as ScheduleType,
              initialValue: args['value'] as String,
              isFavorite: args['isFavorite'] as bool,
            ),
            currentIndex: 0,
          );
        } else {
          // Нет сохранённого избранного → показываем пустой экран
          return MainLayout(
            title: 'Расписание',
            body: const Center(child: Text('Выберите расписание в "Доп. возможностях"')),
            currentIndex: 0,
          );
        }
      },
    );
  }
}
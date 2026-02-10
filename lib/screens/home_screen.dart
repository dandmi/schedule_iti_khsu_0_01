import 'package:flutter/material.dart';

import '../widgets/main_layout.dart';
import 'schedule_screen.dart';
import 'notes_screen.dart';
import 'settings_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _index = 0;

  final _notesKey = GlobalKey<NotesScreenState>();
  final _scheduleKey = GlobalKey<ScheduleScreenState>();

  late final List<Widget> _pages = [
    ScheduleScreen(key: _scheduleKey),
    NotesScreen(key: _notesKey),
    SettingsScreen(
      onScheduleChanged: () {
        // после выбора расписания обновляем ScheduleScreen
        _scheduleKey.currentState?.reload();

        // и переключаем пользователя на вкладку "Расписание"
        setState(() => _index = 0);
      },
    ),
  ];

  void _onTab(int i) => setState(() => _index = i);

  @override
  Widget build(BuildContext context) {
    final fab = _index == 1
        ? FloatingActionButton(
      onPressed: () => _notesKey.currentState?.openCreate(),
      child: const Icon(Icons.add),
    )
        : null;

    return MainLayout(
      currentIndex: _index,
      onIndexChanged: _onTab,
      floatingActionButton: fab,
      body: IndexedStack(
        index: _index,
        children: _pages,
      ),
    );
  }
}

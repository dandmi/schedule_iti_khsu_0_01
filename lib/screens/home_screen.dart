import 'package:flutter/material.dart';

import '../widgets/main_layout.dart';
import 'notes_screen.dart';
import 'schedule_screen.dart';
import 'settings_screen.dart';

class HomeScreen extends StatefulWidget {
  final ThemeMode themeMode;
  final ValueChanged<ThemeMode> onThemeModeChanged;

  const HomeScreen({
    super.key,
    required this.themeMode,
    required this.onThemeModeChanged,
  });

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _index = 0;

  final _notesKey = GlobalKey<NotesScreenState>();
  final _scheduleKey = GlobalKey<ScheduleScreenState>();

  late List<Widget> _pages;

  @override
  void initState() {
    super.initState();
    _buildPages();
  }

  @override
  void didUpdateWidget(covariant HomeScreen oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.themeMode != widget.themeMode ||
        oldWidget.onThemeModeChanged != widget.onThemeModeChanged) {
      _buildPages();
    }
  }

  void _buildPages() {
    _pages = [
      ScheduleScreen(key: _scheduleKey),
      NotesScreen(key: _notesKey),
      SettingsScreen(
        themeMode: widget.themeMode,
        onThemeModeChanged: widget.onThemeModeChanged,
      ),
    ];
  }

  void _onTab(int i) {
    setState(() => _index = i);

    if (i == 1) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _notesKey.currentState?.reload();
      });
    }

    if (i == 0) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _scheduleKey.currentState?.reload();
      });
    }
  }

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
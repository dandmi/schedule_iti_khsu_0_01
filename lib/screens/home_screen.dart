import 'package:flutter/material.dart';

import '../utils/app_refresh_bus.dart';
import '../utils/local_notification_service.dart';
import '../utils/schedule_sync_service.dart';
import '../widgets/main_layout.dart';
import 'notes_screen.dart';
import 'schedule_screen.dart';
import 'settings_screen.dart';
import '../utils/schedule_widget_service.dart';

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

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  int _index = 0;

  final _notesKey = GlobalKey<NotesScreenState>();
  final _scheduleKey = GlobalKey<ScheduleScreenState>();

  late List<Widget> _pages;

  @override
  void initState() {
    super.initState();
    _buildPages();
    _bootstrapData();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) return;

    _refreshBackgroundData(markScheduleChanged: true);
  }

  Future<bool> _refreshBackgroundData({
    required bool markScheduleChanged,
  }) async {
    final online = await ScheduleSyncService.instance.syncOnAppStart();

    try {
      await ScheduleWidgetService.instance.refreshInstalledWidget();
    } catch (_) {}

    try {
      await LocalNotificationService.instance.rescheduleAll();
    } catch (_) {}

    if (mounted && markScheduleChanged && online) {
      AppRefreshBus.markScheduleChanged();
    }

    return online;
  }

  @override
  void didUpdateWidget(covariant HomeScreen oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.themeMode != widget.themeMode ||
        oldWidget.onThemeModeChanged != widget.onThemeModeChanged) {
      setState(() {
        _buildPages();
      });
    }
  }

  Future<void> _bootstrapData() async {
    await _refreshBackgroundData(markScheduleChanged: true);
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
import 'package:flutter/material.dart';
import 'screens/home_screen.dart';
import 'utils/local_notification_service.dart';
import 'utils/theme_storage.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    await LocalNotificationService.instance.initialize();
    await LocalNotificationService.instance.rescheduleAll();
  } catch (_) {}

  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  ThemeMode? _themeMode;

  @override
  void initState() {
    super.initState();
    _loadTheme();
  }

  Future<void> _loadTheme() async {
    final mode = await ThemeStorage.loadThemeMode();
    if (!mounted) return;

    setState(() {
      _themeMode = mode;
    });
  }

  Future<void> _setThemeMode(ThemeMode mode) async {
    await ThemeStorage.saveThemeMode(mode);

    if (!mounted) return;

    setState(() {
      _themeMode = mode;
    });
  }

  @override
  Widget build(BuildContext context) {
    final mode = _themeMode;
    if (mode == null) {
      return const MaterialApp(
        home: Scaffold(
          body: Center(child: CircularProgressIndicator()),
        ),
      );
    }

    return MaterialApp(
      title: 'Расписание ХГУ',
      themeMode: mode,
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.light,
        colorSchemeSeed: Colors.green,
      ),
      darkTheme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        colorSchemeSeed: Colors.green,
      ),
      home: HomeScreen(
        themeMode: mode,
        onThemeModeChanged: _setThemeMode,
      ),
    );
  }
}
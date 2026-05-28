import 'package:flutter/material.dart';
import 'screens/home_screen.dart';
import 'utils/local_notification_service.dart';
import 'utils/theme_storage.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'theme/app_theme.dart';

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
        locale: Locale('ru', 'RU'),
        supportedLocales: [
          Locale('ru', 'RU'),
        ],
        localizationsDelegates: [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
      );
    }

    return MaterialApp(
      title: 'Расписание ХГУ',
      locale: const Locale('ru', 'RU'),
      supportedLocales: const [
        Locale('ru', 'RU'),
      ],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      themeAnimationDuration: Duration.zero,
      themeMode: mode,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      home: HomeScreen(
        themeMode: mode,
        onThemeModeChanged: _setThemeMode,
      ),
    );
  }
}
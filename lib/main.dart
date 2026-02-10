import 'package:flutter/material.dart';

import 'screens/schedule_screen.dart';
import 'screens/notes_screen.dart';
import 'screens/settings_screen.dart';


void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Расписание ХГУ',
      theme: ThemeData(useMaterial3: true),
      initialRoute: '/',
      routes: {
        '/': (context) => const ScheduleScreen(),
        '/second': (context) => const NotesScreen(),
        '/third': (context) => const SettingsScreen(),
      },
    );
  }
}
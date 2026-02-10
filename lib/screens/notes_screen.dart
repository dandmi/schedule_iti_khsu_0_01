import 'package:flutter/material.dart';
import '../widgets/main_layout.dart';

class NotesScreen extends StatelessWidget {
  const NotesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return MainLayout(
      title: 'Заметки',
      body: const Center(child: Text('Заметки пока недоступны')),
      currentIndex: 1,
    );
  }
}
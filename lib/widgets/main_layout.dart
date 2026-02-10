import 'package:flutter/material.dart';

class MainLayout extends StatelessWidget {
  final Widget body;
  final int currentIndex;
  final ValueChanged<int> onIndexChanged;

  final String? title;
  final Widget? floatingActionButton;

  const MainLayout({
    super.key,
    required this.body,
    required this.currentIndex,
    required this.onIndexChanged,
    this.title,
    this.floatingActionButton,
  });

  static const List<String> _titles = [
    'Расписание',
    'Заметки',
    'Доп. возможности',
  ];

  @override
  Widget build(BuildContext context) {
    final appTitle = title ?? _titles[currentIndex];

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.green,
        centerTitle: true,
        title: Text(appTitle),
      ),
      body: body,
      floatingActionButton: floatingActionButton,
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: currentIndex,
        onTap: onIndexChanged,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.schedule), label: 'Расписание'),
          BottomNavigationBarItem(icon: Icon(Icons.book), label: 'Заметки'),
          BottomNavigationBarItem(icon: Icon(Icons.settings), label: 'Доп. возможности'),
        ],
      ),
    );
  }
}

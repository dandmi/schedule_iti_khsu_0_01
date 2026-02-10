import 'package:flutter/material.dart';

class MainLayout extends StatelessWidget {
  final Widget body;
  final int currentIndex;

  /// Если не передали — заголовок берём из currentIndex
  final String? title;

  /// FAB можно передать с экрана (например, в NotesScreen)
  final Widget? floatingActionButton;

  const MainLayout({
    super.key,
    required this.body,
    this.currentIndex = 0,
    this.title,
    this.floatingActionButton,
  });

  static const List<String> _titles = [
    'Расписание',
    'Заметки',
    'Доп. возможности',
  ];

  void _onItemTapped(int index, BuildContext context) {
    switch (index) {
      case 0:
        Navigator.pushNamedAndRemoveUntil(context, '/', (r) => false);
        break;
      case 1:
        Navigator.pushNamedAndRemoveUntil(context, '/second', (r) => false);
        break;
      case 2:
        Navigator.pushNamedAndRemoveUntil(context, '/third', (r) => false);
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final appTitle = title ?? _titles[currentIndex];

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.green,
        title: Text(appTitle),
      ),
      body: body,
      floatingActionButton: floatingActionButton,
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: currentIndex,
        onTap: (index) => _onItemTapped(index, context),
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.schedule), label: 'Расписание'),
          BottomNavigationBarItem(icon: Icon(Icons.book), label: 'Заметки'),
          BottomNavigationBarItem(icon: Icon(Icons.settings), label: 'Доп. возможности'),
        ],
      ),
    );
  }
}

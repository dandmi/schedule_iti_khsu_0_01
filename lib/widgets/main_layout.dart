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
    'Дополнительные возможности',
  ];

  @override
  Widget build(BuildContext context) {
    final appTitle = title ?? _titles[currentIndex];
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).brightness == Brightness.dark
            ? scheme.surface
            : scheme.primary,
        foregroundColor: Theme.of(context).brightness == Brightness.dark
            ? scheme.onSurface
            : scheme.onPrimary,
        surfaceTintColor: Colors.transparent,
        centerTitle: true,
        toolbarHeight: 64,
        title: Text(
          appTitle,
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w500,
            color: Theme.of(context).brightness == Brightness.dark
                ? scheme.onSurface
                : scheme.onPrimary,
          ),
        ),
      ),
      body: body,
      floatingActionButton: floatingActionButton,
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: scheme.surface,
          border: Border(
            top: BorderSide(color: scheme.outlineVariant),
          ),
        ),
        child: BottomNavigationBar(
          currentIndex: currentIndex,
          onTap: onIndexChanged,
          backgroundColor: scheme.surface,
          selectedItemColor: scheme.primary,
          unselectedItemColor: scheme.onSurfaceVariant,
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.schedule),
              label: 'Расписание',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.book),
              label: 'Заметки',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.settings),
              label: 'Доп. возможности',
            ),
          ],
        ),
      ),
    );
  }
}
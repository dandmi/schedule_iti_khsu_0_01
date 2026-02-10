import 'package:flutter/material.dart';

class MainLayout extends StatelessWidget {
  final Widget body;
  final int currentIndex;
  final String title;


  const MainLayout({
    super.key,
    required this.body,
    required this.title,
    this.currentIndex = 0,
  });


  void _onItemTapped(int index, BuildContext context) {
    switch (index) {
      case 0: Navigator.pushNamedAndRemoveUntil(context, '/', (r) => false); break;
      case 1: Navigator.pushNamedAndRemoveUntil(context, '/second', (r) => false); break;
      case 2: Navigator.pushNamedAndRemoveUntil(context, '/third', (r) => false); break;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.green,
        title: Text(title),
        centerTitle: true,
      ),
      body: body,
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
import 'package:flutter/material.dart';
import 'package:schedule_iti_khsu_0_01/widgets/main_layout.dart';
import 'package:schedule_iti_khsu_0_01/database/database_helper.dart';
import 'package:schedule_iti_khsu_0_01/models/favorite_item.dart';
import 'package:schedule_iti_khsu_0_01/screens/add_favorite_screen.dart';
import '../utils/schedule_type.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late Future<List<FavoriteItem>> _favoritesFuture;

  @override
  void initState() {
    super.initState();
    _refreshFavorites();
  }

  void _refreshFavorites() {
    setState(() {
      _favoritesFuture = DatabaseHelper().getFavorites();
    });
  }



  @override
  Widget build(BuildContext context) {
    return MainLayout(
      title: 'Доп. возможности',
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Избранные расписания',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            FutureBuilder<List<FavoriteItem>>(
              future: _favoritesFuture,
              builder: (context, snapshot) {
                if (snapshot.hasData && snapshot.data!.isNotEmpty) {
                  return SizedBox(
                    height: 80,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      itemCount: snapshot.data!.length + 1, // + кнопка
                      itemBuilder: (context, index) {
                        if (index == snapshot.data!.length) {
                          // Кнопка "+"
                          return Card(
                            margin: const EdgeInsets.only(right: 8),
                            child: IconButton(
                              icon: const Icon(Icons.add, size: 32),
                              onPressed: () async {
                                final added = await Navigator.push(
                                  context,
                                  MaterialPageRoute(builder: (context) => const AddFavoriteScreen()),
                                ) as bool?;
                                if (added == true) {
                                  _refreshFavorites(); // обновить список
                                }
                              },
                            ),
                          );
                        }
                        final item = snapshot.data![index];
                        return _buildFavoriteChip(item);
                      },
                    ),
                  );
                } else {
                  // Пустой список + кнопка
                  return Row(
                    children: [
                      const Text('Нет сохранённых расписаний'),
                      const SizedBox(width: 16),
                      ElevatedButton.icon(
                        onPressed: () async {
                          final added = await Navigator.push(
                            context,
                            MaterialPageRoute(builder: (context) => const AddFavoriteScreen()),
                          ) as bool?;
                          if (added == true) {
                            _refreshFavorites();
                          }
                        },
                        icon: const Icon(Icons.add),
                        label: const Text('Добавить'),
                      ),
                    ],
                  );
                }
              },
            ),
          ],
        ),
      ),
      currentIndex: 2,
    );
  }

  Widget _buildFavoriteChip(FavoriteItem item) {
    return Card(
      margin: const EdgeInsets.only(right: 8),
      child: InkWell(
        onTap: () async {
          final prefs = await SharedPreferences.getInstance();

          // Используем .name напрямую
          await prefs.setString('last_favorite_type', item.scheduleType.name);
          await prefs.setString('last_favorite_value', item.name);

          debugPrint('💾 Сохранено: type=${item.scheduleType.name}, value=${item.name}');

          Navigator.pushReplacementNamed(context, '/');
        },
        child: Container(
          width: 120,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                item.scheduleType == ScheduleType.group
                    ? Icons.group
                    : item.scheduleType == ScheduleType.teacher
                    ? Icons.person
                    : Icons.location_on,
                size: 20,
              ),
              const SizedBox(height: 4),
              Text(
                item.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 12),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
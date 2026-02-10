import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../database/database_helper.dart';
import '../models/favorite_item.dart';
import '../screens/add_favorite_screen.dart';
import '../utils/schedule_type.dart';

class SettingsScreen extends StatefulWidget {
  final VoidCallback? onScheduleChanged;

  const SettingsScreen({super.key, this.onScheduleChanged});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _db = DatabaseHelper(); // ✅ микро-оптимизация №1
  late Future<List<FavoriteItem>> _favoritesFuture;

  @override
  void initState() {
    super.initState();
    _favoritesFuture = _db.getFavorites();
  }

  void _refreshFavorites() {
    setState(() {
      _favoritesFuture = _db.getFavorites();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
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
              if (snapshot.connectionState != ConnectionState.done) {
                return const Padding(
                  padding: EdgeInsets.only(top: 16),
                  child: Center(child: CircularProgressIndicator()),
                );
              }

              final favorites = snapshot.data ?? [];

              if (favorites.isEmpty) {
                return Row(
                  children: [
                    const Expanded(child: Text('Нет сохранённых расписаний')),
                    const SizedBox(width: 16),
                    ElevatedButton.icon(
                      onPressed: () async {
                        final added = await Navigator.push<bool>(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const AddFavoriteScreen(),
                          ),
                        );

                        if (!mounted) return; // ✅ микро-оптимизация №2
                        if (added == true) _refreshFavorites();
                      },
                      icon: const Icon(Icons.add),
                      label: const Text('Добавить'),
                    ),
                  ],
                );
              }

              return SizedBox(
                height: 80,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: favorites.length + 1,
                  itemBuilder: (context, index) {
                    if (index == favorites.length) {
                      return Card(
                        margin: const EdgeInsets.only(right: 8),
                        child: IconButton(
                          icon: const Icon(Icons.add, size: 32),
                          onPressed: () async {
                            final added = await Navigator.push<bool>(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const AddFavoriteScreen(),
                              ),
                            );

                            if (!mounted) return; // ✅ микро-оптимизация №2
                            if (added == true) _refreshFavorites();
                          },
                        ),
                      );
                    }

                    return _buildFavoriteChip(favorites[index]);
                  },
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildFavoriteChip(FavoriteItem item) {
    return Card(
      margin: const EdgeInsets.only(right: 8),
      child: InkWell(
        onTap: () async {
          final prefs = await SharedPreferences.getInstance();

          await prefs.setString(
            'last_favorite_type',
            item.scheduleType.name,
          );
          await prefs.setString(
            'last_favorite_value',
            item.name,
          );

          if (!mounted) return; // ✅ микро-оптимизация №2

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Выбрано: ${item.name}')),
          );

          widget.onScheduleChanged?.call();
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

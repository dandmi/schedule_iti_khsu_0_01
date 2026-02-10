// lib/screens/add_favorite_screen.dart
import 'package:flutter/material.dart';
import 'package:schedule_iti_khsu_0_01/api/api_client.dart';
import 'package:schedule_iti_khsu_0_01/database/database_helper.dart';
import 'package:schedule_iti_khsu_0_01/utils/schedule_type.dart';

class AddFavoriteScreen extends StatefulWidget {
  const AddFavoriteScreen({super.key});

  @override
  State<AddFavoriteScreen> createState() => _AddFavoriteScreenState();
}

class _AddFavoriteScreenState extends State<AddFavoriteScreen> {
  final ApiClient _apiClient = ApiClient();
  final TextEditingController _searchController = TextEditingController();

  ScheduleType _scheduleType = ScheduleType.group;
  List<String> _suggestions = [];

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _performSearch(String query) async {
    if (query.isEmpty) {
      setState(() {
        _suggestions = [];
      });
      return;
    }

    try {
      final result = await _apiClient.search(query);
      List<String> items;
      switch (_scheduleType) {
        case ScheduleType.group:
          items = result.names;
          break;
        case ScheduleType.teacher:
          items = result.teacherNames;
          break;
        case ScheduleType.auditory:
          items = result.auditories;
          if (items.isEmpty) {
            items = [query.toUpperCase()];
          }
          break;
      }
      setState(() {
        _suggestions = items;
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Ошибка поиска: $e')),
      );
    }
  }

  void _onItemSelected(String item) async {
    // Сохраняем в БД
    await DatabaseHelper().addFavorite(
      name: item,
      type: _scheduleType.name, // ← 'group', 'teacher', 'auditory'
    );

    // Возвращаем результат
    if (!mounted) return;
    Navigator.pop(context, true); // true = успешно добавлено
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Добавить в избранное')),
      body: Column(
        children: [
          // Переключатель типа
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: SegmentedButton<ScheduleType>(
              segments: const [
                ButtonSegment(value: ScheduleType.group, label: Text('Группа')),
                ButtonSegment(value: ScheduleType.teacher, label: Text('Преподаватель')),
                ButtonSegment(value: ScheduleType.auditory, label: Text('Аудитория')),
              ],
              selected: {_scheduleType},
              onSelectionChanged: (set) {
                setState(() {
                  _scheduleType = set.first;
                  _searchController.clear();
                  _suggestions = [];
                });
              },
            ),
          ),

          // Поиск
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: TextField(
              controller: _searchController,
              onChanged: _performSearch,
              decoration: InputDecoration(
                hintText: 'Введите ${_scheduleType.label.toLowerCase()}...',
                prefixIcon: Icon(
                  _scheduleType == ScheduleType.group
                      ? Icons.group
                      : _scheduleType == ScheduleType.teacher
                      ? Icons.person
                      : Icons.location_on,
                ),
              ),
            ),
          ),

          // Результаты
          Expanded(
            child: _suggestions.isEmpty
                ? const Center(child: Text('Начните вводить запрос'))
                : ListView.builder(
              itemCount: _suggestions.length,
              itemBuilder: (context, index) {
                final item = _suggestions[index];
                return ListTile(
                  title: Text(item),
                  onTap: () => _onItemSelected(item),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
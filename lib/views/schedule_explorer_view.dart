import 'package:flutter/material.dart';
import 'package:schedule_iti_khsu_0_01/api/api_client.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../database/database_helper.dart';
import '../models/schedule_response.dart';
import '../models/lesson.dart';
import '../utils/schedule_type.dart';


class ScheduleExplorerView extends StatefulWidget {
  final ScheduleType? initialType;
  final String? initialValue;
  final bool isFavorite; // ← новый флаг

  const ScheduleExplorerView({
    super.key,
    this.initialType,
    this.initialValue,
    this.isFavorite = false,
  });

  @override
  State<ScheduleExplorerView> createState() => _ScheduleExplorerViewState();
}


class _ScheduleExplorerViewState extends State<ScheduleExplorerView> {
  Future<ScheduleResponse>? _scheduleFuture;
  final ApiClient _apiClient = ApiClient();
  ScheduleType _scheduleType = ScheduleType.group;
  String? _selectedItem;
  DateTime _selectedDate = DateTime.now();
  final TextEditingController _searchController = TextEditingController();
  List<String> _suggestions = [];
  bool _isFavorite = false;

  Future<ScheduleResponse> _getScheduleFuture() {
    // Если уже есть Future — возвращаем его
    if (_scheduleFuture != null) {
      return _scheduleFuture!;
    }

    // Иначе создаём новый
    _scheduleFuture = _loadScheduleFromApiOrCache();
    return _scheduleFuture!;
  }

  @override
  void initState() {
    super.initState();

    // Инициализируем из widget
    _scheduleType = widget.initialType ?? ScheduleType.group;
    _selectedItem = widget.initialValue; // без заглушки!
    _selectedDate = DateTime.now();
    _isFavorite = widget.isFavorite;

    // Если не избранное — подставляем в поиск
    if (_selectedItem != null && !_isFavorite) {
      _searchController.text = _selectedItem!;
    }
  }

  @override
  void didUpdateWidget(covariant ScheduleExplorerView oldWidget) {
    super.didUpdateWidget(oldWidget);

    // Если изменились входные параметры — обновляем состояние
    if (widget.initialType != oldWidget.initialType ||
        widget.initialValue != oldWidget.initialValue ||
        widget.isFavorite != oldWidget.isFavorite) {

      _scheduleType = widget.initialType ?? ScheduleType.group;
      _selectedItem = widget.initialValue ?? 'М-124-1';
      _isFavorite = widget.isFavorite;

      // Сбрасываем Future, чтобы загрузить новое расписание
      _scheduleFuture = null;
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<ScheduleResponse> _loadScheduleFromApiOrCache() async {
    debugPrint('🚀 НАЧАЛО _loadScheduleFromApiOrCache');
    // Добавь эту проверку СРАЗУ
    if (_selectedItem == null) {
      debugPrint('❌ _selectedItem is NULL!');
      throw Exception('Нет выбранного элемента');
    }
    final String dateStr = '${_selectedDate.year}-${_selectedDate.month.toString().padLeft(2, '0')}-${_selectedDate.day.toString().padLeft(2, '0')}';
    final String targetType = _scheduleType.name;
    final String targetValue = _selectedItem!;

    // Проверка входных данных
    if (targetValue.isEmpty) {
      throw Exception('targetValue пустой!');
    }

    if (_selectedItem == null) {
      throw Exception('Нет выбранного элемента!');
    }

    debugPrint('📥 Запрос расписания: $targetType / $targetValue на $dateStr');

    // 1. Попробуем загрузить из кэша
    final cachedLessons = await DatabaseHelper().getSchedule(
      date: dateStr,
      targetType: targetType,
      targetValue: targetValue,
    );

    if (cachedLessons.isNotEmpty) {
      debugPrint('📦 Возвращено из кэша (${cachedLessons.length} занятий)');
      return ScheduleResponse(
        weekday: _determineWeekday(_selectedDate), // или сохрани weekday в БД
        weekNumber: 0,
        lessons: cachedLessons,
      );
    }
    debugPrint('🌐 Кэш пуст, запрашиваем API...');

    // 2. Кэша нет → пробуем загрузить из API
    try {
      late ScheduleResponse response;
      switch (_scheduleType) {
        case ScheduleType.group:
          response = await ApiClient().getGroupSchedule(targetValue, _selectedDate);
          break;
        case ScheduleType.teacher:
          response = await ApiClient().getTeacherSchedule(targetValue, _selectedDate);
          break;
        case ScheduleType.auditory:
          response = await ApiClient().getAuditorySchedule(targetValue, _selectedDate);
          break;
      }
      debugPrint('💾 Сохраняем в БД и возвращаем');

      // 3. Сохраняем в БД при успешной загрузке
      await DatabaseHelper().saveSchedule(
        date: dateStr,
        weekday: response.weekday,
        lessons: response.lessons,
        targetType: targetType,
        targetValue: targetValue,
      );

      return response;
    } catch (e) {
      debugPrint('💥 Ошибка загрузки:');

      // 4. Если API недоступен — пробуем ещё раз прочитать кэш (вдруг появился?)
      // Но скорее всего, кэша нет → покажем "нет данных + нет интернета"
      final fallbackCached = await DatabaseHelper().getSchedule(
        date: dateStr,
        targetType: targetType,
        targetValue: targetValue,
      );

      if (fallbackCached.isNotEmpty) {
        // Маловероятно, но возможно (например, параллельный запрос)
        return ScheduleResponse(
          weekday: _determineWeekday(_selectedDate),
          weekNumber: 0,
          lessons: fallbackCached,
        );
      }

      // 5. Нет кэша и нет интернета → выбрасываем понятную ошибку
      throw Exception('Нет подключения к интернету. Расписание не загружено.');
    }
  }

// Вспомогательная функция для определения дня недели (1=пн, ..., 7=вс)
  int _determineWeekday(DateTime date) {
    // В Dart: Monday = 1, Sunday = 7
    return date.weekday;
  }

  Future<void> _performSearch(String query) async {
    if (query.isEmpty) {
      setState(() {
        _suggestions = [];
      });
      return;
    }

    // Сначала попробуем найти среди избранных (работает без интернета)
    final favorites = await DatabaseHelper().getFavoritesByType(_scheduleType.name);
    final filteredFavorites = favorites
        .where((name) => name.toLowerCase().contains(query.toLowerCase()))
        .toList();

    List<String> apiResults = [];

    // Попробуем загрузить из API, только если есть интернет
    try {
      final result = await _apiClient.search(query);
      switch (_scheduleType) {
        case ScheduleType.group:
          apiResults = result.names;
          break;
        case ScheduleType.teacher:
          apiResults = result.teacherNames;
          break;
        case ScheduleType.auditory:
          apiResults = result.auditories;
          if (apiResults.isEmpty) {
            apiResults = [query.toUpperCase()];
          }
          break;
      }
    } catch (e) {
      // Игнорируем ошибку — оставим только избранные
      debugPrint('Поиск недоступен (нет интернета): $e');
    }

    // Объединим: сначала API-результаты, потом избранные (или наоборот)
    final allSuggestions = [...apiResults, ...filteredFavorites];

    // Уберём дубликаты, сохранив порядок
    final uniqueSuggestions = <String>[];
    for (final item in allSuggestions) {
      if (!uniqueSuggestions.contains(item)) {
        uniqueSuggestions.add(item);
      }
    }

    setState(() {
      _suggestions = uniqueSuggestions;
    });
  }

  void _onItemSelected(String item) {
    // Сохраняем как последнее избранное
    SharedPreferences.getInstance().then((prefs) {
      prefs.setString('last_favorite_type', _scheduleType.name);
      prefs.setString('last_favorite_value', item);
    });

    setState(() {
      _selectedItem = item;
      _suggestions = [];
      _searchController.text = item;
      _scheduleFuture = null;
    });
  }

  void _changeDate(Duration offset) {
    setState(() {
      _selectedDate = _selectedDate.add(offset);
      _scheduleFuture = null;
    });
  }

  void _goToToday() {
    setState(() {
      _selectedDate = DateTime.now();
      _scheduleFuture = null;
    });
  }

  String _formatDate(DateTime date) {
    return '${date.day}.${date.month.toString().padLeft(2, '0')}.${date.year}';
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // 🔸 1. Переключатель типа — ОДИН раз
        if (!_isFavorite)
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: SegmentedButton<ScheduleType>(
              segments: const [
                ButtonSegment<ScheduleType>(value: ScheduleType.group, label: Text('Группа')),
                ButtonSegment<ScheduleType>(value: ScheduleType.teacher, label: Text('Преподаватель')),
                ButtonSegment<ScheduleType>(value: ScheduleType.auditory, label: Text('Аудитория')),
              ],
              selected: {_scheduleType},
              onSelectionChanged: (Set<ScheduleType> newSelection) {
                if (newSelection.isEmpty) return;
                final newValue = newSelection.first;
                setState(() {
                  _scheduleType = newValue;
                  _selectedItem = null;
                  _searchController.clear();
                  _suggestions = [];
                  _scheduleFuture = null;
                });
              },
            ),
          ),

        // 🔸 Заголовок ИЛИ поиск
        if (_isFavorite && _selectedItem != null)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Card(
              child: ListTile(
                leading: Icon(
                  _scheduleType == ScheduleType.group
                      ? Icons.group
                      : _scheduleType == ScheduleType.teacher
                      ? Icons.person
                      : Icons.location_on,
                ),
                title: Text(_selectedItem!),
                subtitle: Text(_scheduleType.label),
              ),
            ),
          )
        else
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

        // 🔸 3. Подсказки — ТОЛЬКО если НЕ избранное
        if (!_isFavorite && _suggestions.isNotEmpty)
          Container(
            height: 150,
            padding: const EdgeInsets.all(8.0),
            color: Colors.grey.shade100,
            child: ListView.builder(
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

        const SizedBox(height: 16),

        // 🔸 4. Расписание (если выбран элемент)
        if (_selectedItem != null) ...[
          // панель даты
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              TextButton.icon(
                onPressed: () => _changeDate(const Duration(days: -1)),
                icon: const Icon(Icons.arrow_back),
                label: const Text('Вчера'),
              ),
              TextButton(
                onPressed: _goToToday,
                child: Text(_formatDate(_selectedDate)),
              ),
              TextButton.icon(
                onPressed: () => _changeDate(const Duration(days: 1)),
                icon: const Icon(Icons.arrow_forward),
                label: const Text('Завтра'),
              ),
            ],
          ),


          const Divider(),
          // Расписание

          Expanded(
            child: FutureBuilder<ScheduleResponse>(
              future: _getScheduleFuture(),
              builder: (context, snapshot) {
                debugPrint('🔄 FutureBuilder.builder вызван, состояние: ${snapshot.connectionState}');
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                } else if (snapshot.hasError) {
                  debugPrint('❌ Ошибка: ${snapshot.error}');
                  return Center(child: Text('Ошибка: ${snapshot.error}'));
                } else if (!snapshot.hasData || snapshot.data!.lessons.isEmpty) {
                  return const Center(
                    child: Text('Нет занятий', style: TextStyle(color: Colors.grey)),
                  );
                } else {
                  final schedule = snapshot.data!;
                  return ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: schedule.lessons.length,
                    itemBuilder: (context, index) {
                      final lesson = schedule.lessons[index];
                      return _buildLessonTile(context, lesson);
                    },
                  );
                }
              },
            ),
          ),
        ] else
          Expanded(
            child: Container(
              color: Colors.red,
              child: const Center(child: Text('❌ НЕТ ВЫБРАННОГО ЭЛЕМЕНТА', style: TextStyle(color: Colors.white))),
            ),
          ),
      ],
    );
  }

  Widget _buildLessonTile(BuildContext context, Lesson lesson) {
    final timeSlots = {
      1: '08:30–10:00',
      2: '10:10–11:40',
      3: '12:00–13:30',
      4: '13:40–15:10',
      5: '15:20–16:50',
      6: '17:00–18:30',
      7: '18:40–20:10',
    };
    final timeStr = timeSlots[lesson.time] ?? '${lesson.time} пара';

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: ListTile(
        title: Text(lesson.subject, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (_scheduleType != ScheduleType.group)
              Text('👥 ${lesson.group.join(', ')}'),
            if (_scheduleType != ScheduleType.teacher)
              Text('👨‍🏫 ${lesson.teacher}'),
            if (_scheduleType != ScheduleType.auditory)
              Text('🚪 ${lesson.auditory}'),
            Text('📚 ${lesson.typeLesson}'),
          ],
        ),
        trailing: Text(timeStr, style: const TextStyle(color: Colors.grey)),
      ),
    );
  }
}
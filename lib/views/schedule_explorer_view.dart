import 'package:flutter/material.dart';
import 'package:schedule_iti_khsu_0_01/api/api_client.dart';
import '../screens/note_edit_screen.dart';
import '../database/database_helper.dart';
import '../models/schedule_response.dart';
import '../models/lesson.dart';
import '../utils/schedule_type.dart';
import '../models/schedule_target.dart';
import '../utils/current_schedule_storage.dart';

class ScheduleExplorerView extends StatefulWidget {
  final ScheduleType initialType;
  final String initialValue;
  final bool isFavorite;

  const ScheduleExplorerView({
    super.key,
    required this.initialType,
    required this.initialValue,
    this.isFavorite = true,
  });

  @override
  State<ScheduleExplorerView> createState() => _ScheduleExplorerViewState();
}

class _DayData {
  final ScheduleResponse schedule;
  final Map<int, ({String start, String end})> slots;
  _DayData(this.schedule, this.slots);
}

class _ScheduleNavigationEntry {
  final ScheduleType type;
  final String value;
  final DateTime date;

  const _ScheduleNavigationEntry({
    required this.type,
    required this.value,
    required this.date,
  });
}


class _ScheduleExplorerViewState extends State<ScheduleExplorerView> {
  final ApiClient _apiClient = ApiClient();
  final DatabaseHelper _db = DatabaseHelper();

  late ScheduleType _scheduleType;
  late String _selectedItem;
  DateTime _selectedDate = DateTime.now();
  Future<_DayData>? _dayFuture;
  final List<_ScheduleNavigationEntry> _history = [];


  @override
  void initState() {
    super.initState();
    _scheduleType = widget.initialType;
    _selectedItem = widget.initialValue;
    _selectedDate = DateTime.now();
  }

  @override
  void didUpdateWidget(covariant ScheduleExplorerView oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (widget.initialType != oldWidget.initialType ||
        widget.initialValue != oldWidget.initialValue ||
        widget.isFavorite != oldWidget.isFavorite) {
      _scheduleType = widget.initialType;
      _selectedItem = widget.initialValue;
      _selectedDate = DateTime.now();
      _dayFuture = null;
      _history.clear();
    }
  }

  // ---------- helpers ----------

  String _dateStr(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  String _formatDate(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}.${d.month.toString().padLeft(2, '0')}.${d.year}';

  IconData _typeIcon(ScheduleType t) => switch (t) {
    ScheduleType.group => Icons.group,
    ScheduleType.teacher => Icons.person,
    ScheduleType.auditory => Icons.location_on,
  };

  Color _typeColor(String typeLesson) {
    final t = typeLesson.toLowerCase().trim();

    // зачеты/экзамены
    if (t.contains('зач') || t.contains('экз')) return Colors.red;

    // лабораторные
    if (t.contains('лаб')) return Colors.orange;

    // практика
    if (t.contains('пр')) return Colors.yellow.shade700;

    // лекция
    if (t.contains('л')) return Colors.green;

    return Colors.black54;
  }


  void _changeDate(int deltaDays) {
    setState(() {
      _selectedDate = _selectedDate.add(Duration(days: deltaDays));
      _dayFuture = null;
    });
  }

  Future<void> _popScheduleHistory() async {
    if (_history.isEmpty) return;

    final previous = _history.removeLast();

    await CurrentScheduleStorage.save(
      ScheduleTarget(
        type: previous.type,
        value: previous.value,
      ),
    );

    if (!mounted) return;

    setState(() {
      _scheduleType = previous.type;
      _selectedItem = previous.value;
      _selectedDate = previous.date;
      _dayFuture = null;
    });
  }

  // ---------- data load ----------

  Future<_DayData> _getDayFuture() {
    _dayFuture ??= _loadDay(forceRefresh: false);
    return _dayFuture!;
  }

  Future<_DayData> _loadDay({required bool forceRefresh}) async {
    final schedule = await _loadScheduleFromApiOrCache(forceRefresh: forceRefresh);
    final slots = await _db.getTimeSlots();
    return _DayData(schedule, slots);
  }




  Future<ScheduleResponse> _loadScheduleFromApiOrCache({required bool forceRefresh}) async {
    final dateStr = _dateStr(_selectedDate);
    final targetType = _scheduleType.name; // group/teacher/auditory
    final targetValue = _selectedItem;

    debugPrint('📅 Запрос: $targetType / $targetValue / $dateStr (force=$forceRefresh)');

    // 1) если не форсим — читаем кэш
    if (!forceRefresh) {
      final cached = await _db.getSchedule(
        date: dateStr,
        targetType: targetType,
        targetValue: targetValue,
      );

      if (cached.isNotEmpty) {
        return ScheduleResponse(
          weekday: _selectedDate.weekday,
          weekNumber: 0,
          lessons: cached,
        );
      }
    } else {
      // при forceRefresh можно очистить старые записи этой даты/цели
      // saveSchedule у тебя и так delete+insert, поэтому отдельно чистить не обязательно
    }

    // 2) грузим из API
    late final ScheduleResponse response;
    switch (_scheduleType) {
      case ScheduleType.group:
        response = await _apiClient.getGroupSchedule(targetValue, _selectedDate);
        break;
      case ScheduleType.teacher:
        response = await _apiClient.getTeacherSchedule(targetValue, _selectedDate);
        break;
      case ScheduleType.auditory:
        response = await _apiClient.getAuditorySchedule(targetValue, _selectedDate);
        break;
    }

    // 3) сохраняем в SQLite
    await _db.saveSchedule(
      date: dateStr,
      weekday: response.weekday,
      lessons: response.lessons,
      targetType: targetType,
      targetValue: targetValue,
    );

    return response;
  }

  Future<void> _refreshSchedule() async {
    final messenger = ScaffoldMessenger.of(context);

    try {
      final freshDay = await _loadDay(forceRefresh: true);

      if (!mounted) return;
      setState(() {
        _dayFuture = Future.value(freshDay);
      });

      messenger.showSnackBar(const SnackBar(content: Text('Расписание обновлено')));
    } catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(SnackBar(content: Text('Не удалось обновить: $e')));
    }
  }

  Future<void> _openCreateNote(Lesson lesson) async {
    final created = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => NoteEditScreen(
          lessonId: lesson.id == 0 ? null : lesson.id,
          initialSubject: lesson.subject,
        ),
      ),
    );

    if (!mounted) return;

    if (created == true) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Заметка сохранена')),
      );
    }
  }

  void _handleHorizontalDragEnd(DragEndDetails details) {
    final velocity = details.primaryVelocity ?? 0;

    if (velocity.abs() < 250) return;

    if (velocity < 0) {
      _changeDate(1);   // свайп влево -> следующий день
    } else {
      _changeDate(-1);  // свайп вправо -> предыдущий день
    }
  }

  Future<void> _openScheduleTarget({
    required ScheduleType type,
    required String value,
  }) async {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return;

    final isSameTarget =
        _scheduleType == type && _selectedItem.trim() == trimmed;

    if (isSameTarget) return;

    _history.add(
      _ScheduleNavigationEntry(
        type: _scheduleType,
        value: _selectedItem,
        date: _selectedDate,
      ),
    );

    await CurrentScheduleStorage.save(
      ScheduleTarget(
        type: type,
        value: trimmed,
      ),
    );

    if (!mounted) return;

    setState(() {
      _scheduleType = type;
      _selectedItem = trimmed;
      _dayFuture = null;
    });
  }

  Future<void> _openTeacherSchedule(String teacher) async {
    await _openScheduleTarget(
      type: ScheduleType.teacher,
      value: teacher,
    );
  }

  Future<void> _openAuditorySchedule(String auditory) async {
    await _openScheduleTarget(
      type: ScheduleType.auditory,
      value: auditory,
    );
  }

  Future<void> _openGroupSchedule(String group) async {
    await _openScheduleTarget(
      type: ScheduleType.group,
      value: group,
    );
  }


  // ---------- UI ----------

  @override
  Widget build(BuildContext context) {
    final header = ScheduleTopHeader(
      title: _selectedItem,
      icon: _typeIcon(_scheduleType),
      onRefresh: _refreshSchedule,
      onTap: null,
      showDropdownChevron: false,
    );

    return PopScope(
      canPop: _history.isEmpty,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        await _popScheduleHistory();
      },
      child: Column(
        children: [
          header,
          _DatePager(
            dateText: _formatDate(_selectedDate),
            onPrev: () => _changeDate(-1),
            onNext: () => _changeDate(1),
          ),
          Expanded(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onHorizontalDragEnd: _handleHorizontalDragEnd,
              child: FutureBuilder<_DayData>(
                future: _getDayFuture(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState != ConnectionState.done) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  if (snapshot.hasError) {
                    return Center(child: Text('Ошибка: ${snapshot.error}'));
                  }

                  final day = snapshot.data!;
                  final lessons = day.schedule.lessons;
                  final slots = day.slots;

                  if (lessons.isEmpty) {
                    return const Center(
                      child: Text('Нет занятий', style: TextStyle(color: Colors.grey)),
                    );
                  }

                  return ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                    itemCount: lessons.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final lesson = lessons[index];

                      return LessonCard(
                        lesson: lesson,
                        number: index + 1,
                        typeColor: _typeColor(lesson.typeLesson),
                        slots: slots,
                        scheduleType: _scheduleType,
                        onTap: () => _openCreateNote(lesson),
                        onTeacherTap: (value) => _openTeacherSchedule(value),
                        onAuditoryTap: (value) => _openAuditorySchedule(value),
                        onGroupTap: (value) => _openGroupSchedule(value),
                      );
                    },
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------- Widgets ----------------

class ScheduleTopHeader extends StatelessWidget {
  final String title;
  final IconData icon;
  final VoidCallback onRefresh;
  final VoidCallback? onTap;
  final bool showDropdownChevron;

  const ScheduleTopHeader({
    super.key,
    required this.title,
    required this.icon,
    required this.onRefresh,
    this.onTap,
    this.showDropdownChevron = false,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.green,
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
          child: Row(
            children: [
              Expanded(
                child: InkWell(
                  borderRadius: BorderRadius.circular(999),
                  onTap: onTap,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.18),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Row(
                      children: [
                        Icon(icon, color: Colors.black87),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: Colors.black87,
                            ),
                          ),
                        ),
                        if (showDropdownChevron) ...[
                          const SizedBox(width: 8),
                          const Icon(Icons.arrow_drop_down, color: Colors.black87),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              IconButton(
                tooltip: 'Обновить',
                onPressed: onRefresh,
                icon: const Icon(Icons.refresh, color: Colors.black87),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DatePager extends StatelessWidget {
  final String dateText;
  final VoidCallback onPrev;
  final VoidCallback onNext;

  const _DatePager({
    required this.dateText,
    required this.onPrev,
    required this.onNext,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: Color(0xFFE6E6E6))),
        ),
        child: Row(
          children: [
            IconButton(onPressed: onPrev, icon: const Icon(Icons.chevron_left)),
            Expanded(
              child: Center(
                child: Text(
                  dateText,
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                ),
              ),
            ),
            IconButton(onPressed: onNext, icon: const Icon(Icons.chevron_right)),
          ],
        ),
      ),
    );
  }
}

class LessonCard extends StatelessWidget {
  final Lesson lesson;
  final int number;
  final Color typeColor;
  final ScheduleType scheduleType;
  final Map<int, ({String start, String end})>? slots;
  final VoidCallback? onTap;
  final ValueChanged<String>? onTeacherTap;
  final ValueChanged<String>? onAuditoryTap;
  final ValueChanged<String>? onGroupTap;

  const LessonCard({
    super.key,
    required this.lesson,
    required this.number,
    required this.typeColor,
    required this.scheduleType,
    this.slots,
    this.onTap,
    this.onTeacherTap,
    this.onAuditoryTap,
    this.onGroupTap,
  });

  @override
  Widget build(BuildContext context) {
    String start = '--:--';
    String end = '--:--';

    if (slots != null) {
      final slot = slots![lesson.time];
      start = slot?.start ?? '--:--';
      end = slot?.end ?? '--:--';
    } else {
      const timeSlots = {
        1: ('08:00', '09:30'),
        2: ('09:50', '11:20'),
        3: ('11:40', '13:10'),
        4: ('13:40', '15:10'),
        5: ('15:20', '16:50'),
        6: ('17:00', '18:30'),
        7: ('18:40', '20:10'),
      };
      final slot = timeSlots[lesson.time];
      start = slot?.$1 ?? '--:--';
      end = slot?.$2 ?? '--:--';
    }

    final showTeacher = scheduleType != ScheduleType.teacher;
    final showAuditory = scheduleType != ScheduleType.auditory;
    final showGroups = scheduleType != ScheduleType.group;

    return Material(
      elevation: 1.2,
      borderRadius: BorderRadius.circular(16),
      color: Colors.white,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.black26),
                ),
                child: Center(
                  child: Text(
                    '$start\n-\n$end',
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      lesson.subject,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      lesson.typeLesson,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: typeColor,
                      ),
                    ),
                    const SizedBox(height: 8),

                    if (showGroups && lesson.group.isNotEmpty) ...[
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          const Text(
                            'Группы:',
                            style: TextStyle(fontSize: 14),
                          ),
                          ...lesson.group.map(
                                (group) => _LessonLinkText(
                              text: group,
                              onTap: () => onGroupTap?.call(group),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                    ],

                    if (showTeacher && lesson.teacher.trim().isNotEmpty) ...[
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          const Text(
                            'Преподаватель:',
                            style: TextStyle(fontSize: 14),
                          ),
                          _LessonLinkText(
                            text: lesson.teacher.trim(),
                            onTap: () => onTeacherTap?.call(lesson.teacher.trim()),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                    ],

                    if (showAuditory && lesson.auditory.trim().isNotEmpty)
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          const Text(
                            'Аудитория:',
                            style: TextStyle(fontSize: 14),
                          ),
                          _LessonLinkText(
                            text: lesson.auditory.trim(),
                            onTap: () => onAuditoryTap?.call(lesson.auditory.trim()),
                          ),
                        ],
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Text(
                '№$number',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}


class _LessonLinkText extends StatelessWidget {
  final String text;
  final VoidCallback onTap;

  const _LessonLinkText({
    required this.text,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          text,
          style: const TextStyle(
            fontSize: 14,
            color: Colors.black87,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }
}


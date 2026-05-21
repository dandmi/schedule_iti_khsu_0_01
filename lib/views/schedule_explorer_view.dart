import 'dart:async';

import 'package:flutter/material.dart';

import '../api/api_client.dart';
import '../database/database_helper.dart';
import '../models/favorite_item.dart';
import '../models/lesson.dart';
import '../models/schedule_response.dart';
import '../models/schedule_target.dart';
import '../screens/add_favorite_screen.dart';
import '../screens/note_edit_screen.dart';
import '../utils/current_schedule_storage.dart';
import '../utils/local_notification_service.dart';
import '../utils/schedule_type.dart';
import '../utils/app_refresh_bus.dart';
import '../utils/schedule_sync_service.dart';
import '../utils/schedule_widget_service.dart';
import 'dart:math' as math;

class ScheduleExplorerView extends StatefulWidget {
  final ScheduleType initialType;
  final String initialValue;
  final bool isFavorite;

  const ScheduleExplorerView({
    super.key,
    required this.initialType,
    required this.initialValue,
    this.isFavorite = false,
  });

  @override
  State<ScheduleExplorerView> createState() => ScheduleExplorerViewState();
}

class ScheduleExplorerViewState extends State<ScheduleExplorerView> {
  final _apiClient = ApiClient();
  final _db = DatabaseHelper();

  late ScheduleType _scheduleType;
  late String _selectedItem;
  DateTime _selectedDate = DateTime.now();

  Future<_DayData>? _dayFuture;
  Future<Set<String>>? _noteSubjectsFuture;

  final List<_ScheduleNavigationEntry> _history = [];

  Timer? _clockTimer;
  DateTime _now = DateTime.now();
  Brightness? _lastBrightness;
  double? _horizontalDragStartX;

  static const double _systemGestureFallbackWidth = 32.0;

  @override
  void initState() {
    super.initState();
    _scheduleType = widget.initialType;
    _selectedItem = widget.initialValue;
    _selectedDate = DateTime.now();

    _reloadSideData();
    _startClock();
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
      _reloadSideData();
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    final brightness = Theme.of(context).brightness;

    if (_lastBrightness != null && _lastBrightness != brightness) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        setState(() {});
      });
    }

    _lastBrightness = brightness;
  }

  @override
  void dispose() {
    _clockTimer?.cancel();
    super.dispose();
  }

  Future<void> refreshExternalData() async {
    if (!mounted) return;

    setState(() {
      _reloadSideData();
      _dayFuture = null;
    });
  }

  void _reloadSideData() {
    _noteSubjectsFuture = _loadNoteSubjects();
  }

  void _startClock() {
    _clockTimer?.cancel();
    _clockTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (!mounted) return;
      setState(() {
        _now = DateTime.now();
      });
    });
  }

  Future<Set<String>> _loadNoteSubjects() async {
    final notes = await _db.getNotes();

    return notes
        .map((n) => (n.subject ?? '').trim())
        .where((s) => s.isNotEmpty)
        .map(_normalizeSubject)
        .toSet();
  }

  String _normalizeSubject(String value) {
    return value
        .trim()
        .toLowerCase()
        .replaceAll(RegExp(r'\s+'), ' ');
  }

  Future<_DayData> _getDayData({required bool forceRefresh}) async {
    final slots = await _db.getTimeSlots();
    final schedule =
    await _loadScheduleFromApiOrCache(forceRefresh: forceRefresh);

    return _DayData(schedule: schedule, slots: slots);
  }

  Future<_DayData> _getDayFuture() {
    _dayFuture ??= _getDayData(forceRefresh: false);
    return _dayFuture!;
  }

  Future<ScheduleResponse> _loadScheduleFromApiOrCache({
    required bool forceRefresh,
  }) async {
    final dateStr =
        '${_selectedDate.year}-${_selectedDate.month.toString().padLeft(2, '0')}-${_selectedDate.day.toString().padLeft(2, '0')}';

    final targetType = _scheduleType.name;
    final targetValue = _selectedItem;

    final hasInternet = await _apiClient.hasInternetConnection();

    if (hasInternet) {
      try {
        final response = await _apiClient.fetchSchedule(
          type: _scheduleType,
          value: targetValue,
          date: _selectedDate,
        );

        await _db.saveSchedule(
          date: dateStr,
          weekday: response.weekday,
          lessons: response.lessons,
          targetType: targetType,
          targetValue: targetValue,
        );

        return response;
      } catch (_) {
      }
    }

    final cachedLessons = await _db.getSchedule(
      date: dateStr,
      targetType: targetType,
      targetValue: targetValue,
    );

    final hasSnapshot = await _db.hasScheduleSnapshot(
      date: dateStr,
      targetType: targetType,
      targetValue: targetValue,
    );

    if (hasSnapshot) {
      return ScheduleResponse(
        weekday: _selectedDate.weekday,
        weekNumber: 0,
        lessons: cachedLessons,
      );
    }

    if (!hasInternet) {
      throw Exception('Нет подключения к интернету и нет сохранённых данных на эту дату.');
    }

    throw Exception('Не удалось обновить расписание.');
  }

  Future<void> _refreshSchedule() async {
    setState(() {
      _dayFuture = _getDayData(forceRefresh: true);
    });
  }
  String _scheduleErrorMessage(Object? error) {
    final raw = error.toString();

    if (raw.contains('Нет подключения к интернету') ||
        raw.contains('нет сохранённых данных')) {
      return 'Расписание на выбранную дату ещё не загружено. '
          'Подключитесь к интернету и повторите попытку.';
    }

    if (raw.contains('Не удалось обновить расписание')) {
      return 'Не удалось загрузить расписание. '
          'Проверьте подключение к интернету и повторите попытку.';
    }

    return 'Не удалось получить данные расписания. '
        'Попробуйте обновить страницу.';
  }

  void _changeDate(int deltaDays) {
    setState(() {
      _selectedDate = _selectedDate.add(Duration(days: deltaDays));
      _dayFuture = null;
    });
  }

  Future<void> _openCreateNote(Lesson lesson) async {
    final created = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => NoteEditScreen(
          initialSubject: lesson.subject,
        ),
      ),
    );

    if (!mounted) return;

    if (created == true) {
      setState(() {
        _noteSubjectsFuture = _loadNoteSubjects();
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Заметка сохранена')),
      );
    }
  }

  void _handleHorizontalDragStart(DragStartDetails details) {
    _horizontalDragStartX = details.globalPosition.dx;
  }

  bool _startedFromSystemGestureEdge(double velocity) {
    final startX = _horizontalDragStartX;
    if (startX == null) return false;

    final mediaQuery = MediaQuery.of(context);
    final screenWidth = mediaQuery.size.width;
    final gestureInsets = mediaQuery.systemGestureInsets;

    final leftEdgeWidth = math.max(
      gestureInsets.left,
      _systemGestureFallbackWidth,
    );
    final rightEdgeWidth = math.max(
      gestureInsets.right,
      _systemGestureFallbackWidth,
    );

    if (velocity > 0 && startX <= leftEdgeWidth) return true;
    if (velocity < 0 && startX >= screenWidth - rightEdgeWidth) return true;

    return false;
  }

  void _handleHorizontalDragEnd(DragEndDetails details) {
    final velocity = details.primaryVelocity ?? 0;

    if (velocity.abs() < 250 || _startedFromSystemGestureEdge(velocity)) {
      _horizontalDragStartX = null;
      return;
    }

    if (velocity < 0) {
      _changeDate(1);
    } else {
      _changeDate(-1);
    }

    _horizontalDragStartX = null;
  }

  Future<void> _openScheduleTarget({
    required ScheduleType type,
    required String value,
    bool addToHistory = true,
    bool saveAsCurrent = false,
  }) async {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return;

    final isSameTarget =
        _scheduleType == type && _selectedItem.trim() == trimmed;

    if (isSameTarget) return;

    if (addToHistory) {
      _history.add(
        _ScheduleNavigationEntry(
          type: _scheduleType,
          value: _selectedItem,
          date: _selectedDate,
        ),
      );
    }

    if (!mounted) return;

    setState(() {
      _scheduleType = type;
      _selectedItem = trimmed;
      _dayFuture = null;
    });

    if (saveAsCurrent) {
      await CurrentScheduleStorage.save(
        ScheduleTarget(
          type: type,
          value: trimmed,
        ),
      );

      _runCurrentScheduleSideEffects();
    }
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

  Future<void> _popScheduleHistory() async {
    if (_history.isEmpty) return;

    final previous = _history.removeLast();

    if (!mounted) return;

    setState(() {
      _scheduleType = previous.type;
      _selectedItem = previous.value;
      _selectedDate = previous.date;
      _dayFuture = null;
    });

  }

  void _runCurrentScheduleSideEffects() {
    unawaited(() async {
      try {
        await ScheduleSyncService.instance.syncCurrentAndFavoritesFutureDates();
        await LocalNotificationService.instance.rescheduleAll();
        await ScheduleWidgetService.instance.refreshInstalledWidget();
      } catch (_) {
        // Не блокируем выбор расписания из-за фоновой синхронизации.
      }
    }());
  }

  Future<void> _openFavoritesSheet() async {
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (sheetContext) {
        return _FavoritesBottomSheet(
          db: _db,
          activeType: _scheduleType,
          activeValue: _selectedItem,
          onTargetChosen: (target) async {
            if (Navigator.of(sheetContext).canPop()) {
              Navigator.of(sheetContext).pop();
            }

            await _openScheduleTarget(
              type: target.type,
              value: target.value,
              addToHistory: false,
              saveAsCurrent: true,
            );

            if (!mounted) return;

            AppRefreshBus.markScheduleChanged();

            setState(() {
              _reloadSideData();
            });
          },
        );
      },
    );
  }

  IconData _typeIcon(ScheduleType type) {
    switch (type) {
      case ScheduleType.group:
        return Icons.groups_rounded;
      case ScheduleType.teacher:
        return Icons.person_rounded;
      case ScheduleType.auditory:
        return Icons.meeting_room_rounded;
    }
  }

  String _formatDate(DateTime date) {
    const months = [
      '',
      'января',
      'февраля',
      'марта',
      'апреля',
      'мая',
      'июня',
      'июля',
      'августа',
      'сентября',
      'октября',
      'ноября',
      'декабря',
    ];

    return '${date.day} ${months[date.month]} ${date.year}';
  }

  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  _LessonTiming? _resolveLessonTiming(
      Lesson lesson,
      Map<int, ({String start, String end})> slots,
      ) {
    final slot = slots[lesson.time];
    if (slot == null) return null;

    final startParts = slot.start.split(':');
    final endParts = slot.end.split(':');

    if (startParts.length != 2 || endParts.length != 2) return null;

    final startHour = int.tryParse(startParts[0]);
    final startMinute = int.tryParse(startParts[1]);
    final endHour = int.tryParse(endParts[0]);
    final endMinute = int.tryParse(endParts[1]);

    if (startHour == null ||
        startMinute == null ||
        endHour == null ||
        endMinute == null) {
      return null;
    }

    final start = DateTime(
      _selectedDate.year,
      _selectedDate.month,
      _selectedDate.day,
      startHour,
      startMinute,
    );

    final end = DateTime(
      _selectedDate.year,
      _selectedDate.month,
      _selectedDate.day,
      endHour,
      endMinute,
    );

    final isToday = _isSameDay(_selectedDate, _now);
    final isCurrent =
        isToday && !_now.isBefore(start) && _now.isBefore(end);

    double progress = 0;
    if (isCurrent) {
      final totalMs = end.millisecondsSinceEpoch - start.millisecondsSinceEpoch;
      final doneMs = _now.millisecondsSinceEpoch - start.millisecondsSinceEpoch;
      if (totalMs > 0) {
        progress = (doneMs / totalMs).clamp(0.0, 1.0);
      }
    }

    return _LessonTiming(
      start: start,
      end: end,
      isCurrent: isCurrent,
      progress: progress,
      startLabel: slot.start,
      endLabel: slot.end,
    );
  }

  _LessonBlockStyle _lessonBlockStyle(
      BuildContext context,
      String typeLesson,
      ) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final t = typeLesson.toLowerCase().trim();

    if (t.contains('зач') || t.contains('экз')) {
      return isDark
          ? const _LessonBlockStyle(
        background: Color(0xFF4B2228),
        border: Color(0xFF8F4A56),
        accent: Color(0xFFFFB3C1),
      )
          : const _LessonBlockStyle(
        background: Color(0xFFFFE6EA),
        border: Color(0xFFE7B5BF),
        accent: Color(0xFF9C2F45),
      );
    }

    if (t.contains('лаб')) {
      return isDark
          ? const _LessonBlockStyle(
        background: Color(0xFF3A2D16),
        border: Color(0xFF7B6335),
        accent: Color(0xFFFFD98A),
      )
          : const _LessonBlockStyle(
        background: Color(0xFFFFF2D6),
        border: Color(0xFFE6D09B),
        accent: Color(0xFF8A6200),
      );
    }

    if (t.contains('пр')) {
      return isDark
          ? const _LessonBlockStyle(
        background: Color(0xFF24344A),
        border: Color(0xFF4A6D98),
        accent: Color(0xFFB8D5FF),
      )
          : const _LessonBlockStyle(
        background: Color(0xFFE6F0FF),
        border: Color(0xFFB8CCE8),
        accent: Color(0xFF2C5EAA),
      );
    }

    if (t.contains('л')) {
      return isDark
          ? const _LessonBlockStyle(
        background: Color(0xFF203629),
        border: Color(0xFF4B7B5E),
        accent: Color(0xFFBDE8C7),
      )
          : const _LessonBlockStyle(
        background: Color(0xFFE4F5E8),
        border: Color(0xFFB8D8BF),
        accent: Color(0xFF2B7642),
      );
    }

    return isDark
        ? const _LessonBlockStyle(
      background: Color(0xFF2E2E31),
      border: Color(0xFF55585E),
      accent: Color(0xFFE6E7EA),
    )
        : const _LessonBlockStyle(
      background: Color(0xFFF1F2F4),
      border: Color(0xFFD7DADE),
      accent: Color(0xFF2B2E33),
    );
  }

  @override
  Widget build(BuildContext context) {
    final header = ScheduleTopHeader(
      title: _selectedItem,
      icon: _typeIcon(_scheduleType),
      onRefresh: _refreshSchedule,
      onTap: _openFavoritesSheet,
      showDropdownChevron: true,
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
              onHorizontalDragStart: _handleHorizontalDragStart,
              onHorizontalDragEnd: _handleHorizontalDragEnd,
              child: FutureBuilder<_DayData>(
                future: _getDayFuture(),
                builder: (context, daySnapshot) {
                  if (daySnapshot.connectionState != ConnectionState.done) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  if (daySnapshot.hasError) {
                    return _ScheduleLoadError(
                      message: _scheduleErrorMessage(daySnapshot.error),
                      onRetry: _refreshSchedule,
                    );
                  }

                  final day = daySnapshot.data!;
                  final lessons = day.schedule.lessons;
                  final slots = day.slots;

                  if (lessons.isEmpty) {
                    return Center(
                      child: Text(
                        'Нет занятий',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    );
                  }

                  return FutureBuilder<Set<String>>(
                    future: _noteSubjectsFuture,
                    builder: (context, noteSnapshot) {
                      final noteSubjects = noteSnapshot.data ?? <String>{};

                      return ListView.separated(
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                        itemCount: lessons.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 12),
                        itemBuilder: (context, index) {
                          final lesson = lessons[index];
                          final timing = _resolveLessonTiming(lesson, slots);
                          final style = _lessonBlockStyle(
                            context,
                            lesson.typeLesson,
                          );

                          final hasNote = noteSubjects.contains(
                            _normalizeSubject(lesson.subject),
                          );

                          return _LessonCard(
                            lesson: lesson,
                            style: style,
                            scheduleType: _scheduleType,
                            timing: timing,
                            hasNote: hasNote,
                            onTap: () => _openCreateNote(lesson),
                            onTeacherTap: (value) => _openTeacherSchedule(value),
                            onAuditoryTap: (value) =>
                                _openAuditorySchedule(value),
                            onGroupTap: (value) => _openGroupSchedule(value),
                          );
                        },
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

class _DayData {
  final ScheduleResponse schedule;
  final Map<int, ({String start, String end})> slots;

  const _DayData({
    required this.schedule,
    required this.slots,
  });
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

class _LessonTiming {
  final DateTime start;
  final DateTime end;
  final bool isCurrent;
  final double progress;
  final String startLabel;
  final String endLabel;

  const _LessonTiming({
    required this.start,
    required this.end,
    required this.isCurrent,
    required this.progress,
    required this.startLabel,
    required this.endLabel,
  });
}

class _LessonBlockStyle {
  final Color background;
  final Color border;
  final Color accent;

  const _LessonBlockStyle({
    required this.background,
    required this.border,
    required this.accent,
  });
}

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
    final scheme = Theme.of(context).colorScheme;

    return Material(
      color: scheme.primaryContainer,
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
          child: Row(
            children: [
              Expanded(
                child: InkWell(
                  borderRadius: BorderRadius.circular(18),
                  onTap: onTap,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: scheme.onPrimaryContainer.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(
                        color:
                        scheme.onPrimaryContainer.withValues(alpha: 0.10),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(icon, color: scheme.onPrimaryContainer),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: scheme.onPrimaryContainer,
                            ),
                          ),
                        ),
                        if (showDropdownChevron) ...[
                          const SizedBox(width: 8),
                          Icon(
                            Icons.arrow_drop_down_rounded,
                            color: scheme.onPrimaryContainer,
                          ),
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
                icon: Icon(
                  Icons.refresh_rounded,
                  color: scheme.onPrimaryContainer,
                ),
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
    final scheme = Theme.of(context).colorScheme;

    return Material(
      color: scheme.surface,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(color: scheme.outlineVariant),
          ),
        ),
        child: Row(
          children: [
            _DatePagerButton(
              icon: Icons.chevron_left_rounded,
              onTap: onPrev,
            ),
            Expanded(
              child: Center(
                child: Text(
                  dateText,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: scheme.onSurface,
                  ),
                ),
              ),
            ),
            _DatePagerButton(
              icon: Icons.chevron_right_rounded,
              onTap: onNext,
            ),
          ],
        ),
      ),
    );
  }
}

class _DatePagerButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _DatePagerButton({
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Material(
      color: scheme.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: SizedBox(
          width: 44,
          height: 44,
          child: Icon(icon),
        ),
      ),
    );
  }
}

class _ScheduleLoadError extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _ScheduleLoadError({
    required this.message,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Card(
            elevation: 0,
            color: scheme.surfaceContainerHighest.withValues(alpha: 0.65),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
              side: BorderSide(color: scheme.outlineVariant),
            ),
            child: Padding(
              padding: const EdgeInsets.all(22),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.cloud_off_rounded,
                    size: 52,
                    color: scheme.primary,
                  ),
                  const SizedBox(height: 14),
                  Text(
                    'Расписание не загружено',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    message,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 18),
                  FilledButton.icon(
                    onPressed: onRetry,
                    icon: const Icon(Icons.refresh_rounded),
                    label: const Text('Повторить'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _LessonCard extends StatelessWidget {
  final Lesson lesson;
  final _LessonBlockStyle style;
  final ScheduleType scheduleType;
  final _LessonTiming? timing;
  final bool hasNote;
  final VoidCallback? onTap;
  final ValueChanged<String>? onTeacherTap;
  final ValueChanged<String>? onAuditoryTap;
  final ValueChanged<String>? onGroupTap;

  const _LessonCard({
    required this.lesson,
    required this.style,
    required this.scheduleType,
    required this.timing,
    required this.hasNote,
    this.onTap,
    this.onTeacherTap,
    this.onAuditoryTap,
    this.onGroupTap,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    final showTeacher = scheduleType != ScheduleType.teacher;
    final showAuditory = scheduleType != ScheduleType.auditory;
    final showGroups = scheduleType != ScheduleType.group;
    final isCurrent = timing?.isCurrent ?? false;

    return Material(
      color: style.background,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Stack(
          children: [
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: style.border),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _LessonTimeCircle(
                    startText: timing?.startLabel ?? '--:--',
                    endText: timing?.endLabel ?? '--:--',
                    isCurrent: isCurrent,
                    progress: timing?.progress ?? 0,
                    accent: style.accent,
                    borderColor: style.border,
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Text(
                                lesson.subject,
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w800,
                                  color: scheme.onSurface,
                                ),
                              ),
                            ),
                            if (hasNote) ...[
                              const SizedBox(width: 8),
                              Icon(
                                Icons.sticky_note_2_rounded,
                                size: 18,
                                color: scheme.onSurfaceVariant,
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          lesson.typeLesson,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: style.accent,
                          ),
                        ),
                        const SizedBox(height: 10),
                        if (showGroups && lesson.group.isNotEmpty) ...[
                          Wrap(
                            spacing: 6,
                            runSpacing: 6,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              Text(
                                'Группы:',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: scheme.onSurfaceVariant,
                                ),
                              ),
                              ...lesson.group.map(
                                    (group) => _LessonLinkChip(
                                  text: group,
                                  onTap: () => onGroupTap?.call(group),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                        ],
                        if (showTeacher && lesson.teacher.trim().isNotEmpty) ...[
                          Wrap(
                            spacing: 6,
                            runSpacing: 6,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              Text(
                                'Преподаватель:',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: scheme.onSurfaceVariant,
                                ),
                              ),
                              _LessonLinkChip(
                                text: lesson.teacher.trim(),
                                onTap: () =>
                                    onTeacherTap?.call(lesson.teacher.trim()),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                        ],
                        if (showAuditory && lesson.auditory.trim().isNotEmpty)
                          Wrap(
                            spacing: 6,
                            runSpacing: 6,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              Text(
                                'Аудитория:',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: scheme.onSurfaceVariant,
                                ),
                              ),
                              _LessonLinkChip(
                                text: lesson.auditory.trim(),
                                onTap: () =>
                                    onAuditoryTap?.call(lesson.auditory.trim()),
                              ),
                            ],
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            if (isCurrent)
              Positioned.fill(
                child: IgnorePointer(
                  child: Container(
                    margin: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: style.accent,
                        width: 2,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _LessonTimeCircle extends StatelessWidget {
  final String startText;
  final String endText;
  final bool isCurrent;
  final double progress;
  final Color accent;
  final Color borderColor;

  const _LessonTimeCircle({
    required this.startText,
    required this.endText,
    required this.isCurrent,
    required this.progress,
    required this.accent,
    required this.borderColor,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return SizedBox(
      width: 74,
      height: 74,
      child: Stack(
        alignment: Alignment.center,
        children: [
          CustomPaint(
            size: const Size(74, 74),
            painter: _LessonTimeRingPainter(
              isCurrent: isCurrent,
              progress: progress,
              baseColor: borderColor,
              darkColor: Theme.of(context).brightness == Brightness.dark
                  ? Colors.black.withValues(alpha: 0.55)
                  : Colors.black.withValues(alpha: 0.45),
            ),
          ),
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: scheme.surface.withValues(alpha: 0.72),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  startText,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: scheme.onSurface,
                  ),
                ),
                Container(
                  width: 6,
                  height: 6,
                  margin: const EdgeInsets.symmetric(vertical: 4),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: accent,
                  ),
                ),
                Text(
                  endText,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _LessonTimeRingPainter extends CustomPainter {
  final bool isCurrent;
  final double progress;
  final Color baseColor;
  final Color darkColor;

  const _LessonTimeRingPainter({
    required this.isCurrent,
    required this.progress,
    required this.baseColor,
    required this.darkColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    const strokeWidth = 5.0;
    final rect = Offset.zero & size;

    final basePaint = Paint()
      ..color = baseColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(
      rect.deflate(strokeWidth / 2),
      -math.pi / 2,
      math.pi * 2,
      false,
      basePaint,
    );

    if (!isCurrent) return;

    final remaining = (1 - progress).clamp(0.0, 1.0);

    final darkPaint = Paint()
      ..color = darkColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(
      rect.deflate(strokeWidth / 2),
      -math.pi / 2,
      -math.pi * 2 * remaining,
      false,
      darkPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _LessonTimeRingPainter oldDelegate) {
    return oldDelegate.isCurrent != isCurrent ||
        oldDelegate.progress != progress ||
        oldDelegate.baseColor != baseColor ||
        oldDelegate.darkColor != darkColor;
  }
}

class _LessonLinkChip extends StatelessWidget {
  final String text;
  final VoidCallback onTap;

  const _LessonLinkChip({
    required this.text,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: scheme.surface.withValues(alpha: 0.55),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          text,
          style: TextStyle(
            fontSize: 14,
            color: scheme.onSurface,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }
}

class _FavoritesBottomSheet extends StatefulWidget {
  final DatabaseHelper db;
  final ScheduleType activeType;
  final String activeValue;
  final Future<void> Function(ScheduleTarget target) onTargetChosen;

  const _FavoritesBottomSheet({
    required this.db,
    required this.activeType,
    required this.activeValue,
    required this.onTargetChosen,
  });

  @override
  State<_FavoritesBottomSheet> createState() => _FavoritesBottomSheetState();
}

class _FavoritesBottomSheetState extends State<_FavoritesBottomSheet> {
  bool _isLoading = true;
  List<FavoriteItem> _favorites = [];

  @override
  void initState() {
    super.initState();
    _loadFavorites();
  }

  Future<void> _loadFavorites() async {
    final favorites = await widget.db.getFavorites();

    if (!mounted) return;

    setState(() {
      _favorites = favorites;
      _isLoading = false;
    });
  }

  IconData _iconFor(ScheduleType type) {
    switch (type) {
      case ScheduleType.group:
        return Icons.groups_rounded;
      case ScheduleType.teacher:
        return Icons.person_rounded;
      case ScheduleType.auditory:
        return Icons.meeting_room_rounded;
    }
  }

  Future<void> _deleteFavorite(FavoriteItem item) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Удаление избранного'),
          content: Text('Удалить "${item.name}" из избранного?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Отмена'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Удалить'),
            ),
          ],
        );
      },
    );

    if (confirmed != true) return;

    await widget.db.removeFavorite(item.id);

    if (!mounted) return;

    setState(() {
      _favorites.removeWhere((e) => e.id == item.id);
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Удалено: ${item.name}')),
    );
  }

  Future<void> _addFavorite() async {
    final target = await Navigator.of(context).push<ScheduleTarget>(
      MaterialPageRoute(
        builder: (_) => const AddFavoriteScreen(),
      ),
    );

    if (!mounted || target == null) return;

    await _loadFavorites();

    if (!mounted) return;

    await widget.onTargetChosen(target);
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const SafeArea(
        child: SizedBox(
          height: 240,
          child: Center(child: CircularProgressIndicator()),
        ),
      );
    }

    return SafeArea(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxHeight: 480),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const ListTile(
              title: Text(
                'Избранные расписания',
                style: TextStyle(fontWeight: FontWeight.w800),
              ),
            ),
            Flexible(
              child: ListView(
                shrinkWrap: true,
                children: [
                  for (final item in _favorites)
                    ListTile(
                      leading: Icon(_iconFor(item.scheduleType)),
                      title: Text(item.name),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (item.scheduleType == widget.activeType &&
                              item.name == widget.activeValue)
                            const Icon(
                              Icons.check_circle_rounded,
                              color: Colors.green,
                            ),
                          IconButton(
                            tooltip: 'Удалить',
                            onPressed: () => _deleteFavorite(item),
                            icon: const Icon(Icons.delete_outline_rounded),
                          ),
                        ],
                      ),
                      onTap: () => widget.onTargetChosen(
                        ScheduleTarget(
                          type: item.scheduleType,
                          value: item.name,
                        ),
                      ),
                    ),
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(Icons.add_rounded),
                    title: const Text('Добавить в избранное'),
                    onTap: _addFavorite,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
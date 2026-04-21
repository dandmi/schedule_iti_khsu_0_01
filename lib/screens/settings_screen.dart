import 'package:flutter/material.dart';
import '../database/database_helper.dart';
import '../models/favorite_item.dart';
import '../models/schedule_target.dart';
import '../screens/add_favorite_screen.dart';
import '../utils/current_schedule_storage.dart';
import '../utils/schedule_type.dart';

class SettingsScreen extends StatefulWidget {
  final ThemeMode themeMode;
  final ValueChanged<ThemeMode> onThemeModeChanged;
  final VoidCallback? onScheduleChanged;

  const SettingsScreen({
    super.key,
    required this.themeMode,
    required this.onThemeModeChanged,
    this.onScheduleChanged,
  });

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _db = DatabaseHelper();
  late Future<List<FavoriteItem>> _favoritesFuture;

  String? _activeType;
  String? _activeValue;

  final _scrollCtrl = ScrollController();
  bool _canScrollLeft = false;
  bool _canScrollRight = false;

  @override
  void initState() {
    super.initState();
    _favoritesFuture = _db.getFavorites();
    _loadActive();
    _scrollCtrl.addListener(_updateScrollHints);
  }

  @override
  void dispose() {
    _scrollCtrl.removeListener(_updateScrollHints);
    _scrollCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadActive() async {
    final target = await CurrentScheduleStorage.load();

    if (!mounted) return;

    setState(() {
      _activeType = target?.type.name;
      _activeValue = target?.value;
    });
  }

  void _updateScrollHints() {
    if (!_scrollCtrl.hasClients) return;

    final pos = _scrollCtrl.position;
    final left = pos.pixels > 2;
    final right = pos.pixels < (pos.maxScrollExtent - 2);

    if (left != _canScrollLeft || right != _canScrollRight) {
      setState(() {
        _canScrollLeft = left;
        _canScrollRight = right;
      });
    }
  }

  void _refreshFavorites() {
    setState(() {
      _favoritesFuture = _db.getFavorites();
    });
    _loadActive();
  }

  String _themeLabel(ThemeMode mode) {
    switch (mode) {
      case ThemeMode.dark:
        return 'Тёмная';
      case ThemeMode.light:
        return 'Светлая';
      case ThemeMode.system:
        return 'Системная';
    }
  }

  Future<void> _confirmDelete(FavoriteItem item) async {
    final messenger = ScaffoldMessenger.of(context);

    final bool? ok = await showModalBottomSheet<bool>(
      context: context,
      showDragHandle: true,
      builder: (ctx) {
        final icon = item.scheduleType == ScheduleType.group
            ? Icons.group
            : item.scheduleType == ScheduleType.teacher
            ? Icons.person
            : Icons.location_on;

        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  leading: Icon(icon),
                  title: Text(item.name),
                  subtitle: const Text('Удалить из избранного?'),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.of(ctx).pop(false),
                        child: const Text('Отмена'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: () => Navigator.of(ctx).pop(true),
                        icon: const Icon(Icons.delete_outline),
                        label: const Text('Удалить'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );

    if (ok != true) return;

    await _db.removeFavorite(item.id);

    if (!mounted) return;

    _refreshFavorites();

    messenger.showSnackBar(
      SnackBar(content: Text('Удалено: ${item.name}')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Оформление',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.45),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Цветовая схема',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    ChoiceChip(
                      label: const Text('Светлая'),
                      selected: widget.themeMode == ThemeMode.light,
                      onSelected: (_) => widget.onThemeModeChanged(ThemeMode.light),
                    ),
                    ChoiceChip(
                      label: const Text('Тёмная'),
                      selected: widget.themeMode == ThemeMode.dark,
                      onSelected: (_) => widget.onThemeModeChanged(ThemeMode.dark),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'Текущая тема: ${_themeLabel(widget.themeMode)}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

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

                        if (!mounted) return;
                        if (added == true) _refreshFavorites();
                      },
                      icon: const Icon(Icons.add),
                      label: const Text('Добавить'),
                    ),
                  ],
                );
              }

              WidgetsBinding.instance
                  .addPostFrameCallback((_) => _updateScrollHints());

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    height: 52,
                    child: Stack(
                      children: [
                        ListView.separated(
                          controller: _scrollCtrl,
                          scrollDirection: Axis.horizontal,
                          physics: const BouncingScrollPhysics(),
                          padding: const EdgeInsets.only(right: 8),
                          itemCount: favorites.length + 1,
                          separatorBuilder: (_, __) =>
                          const SizedBox(width: 8),
                          itemBuilder: (context, index) {
                            if (index == favorites.length) {
                              return _AddChip(
                                onTap: () async {
                                  final added = await Navigator.push<bool>(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) =>
                                      const AddFavoriteScreen(),
                                    ),
                                  );

                                  if (!mounted) return;
                                  if (added == true) _refreshFavorites();
                                },
                              );
                            }

                            final item = favorites[index];
                            final isActive = _activeType ==
                                item.scheduleType.name &&
                                _activeValue == item.name;

                            return _FavoriteChip(
                              item: item,
                              isActive: isActive,
                              onTap: () async {
                                final messenger =
                                ScaffoldMessenger.of(context);

                                final target = ScheduleTarget(
                                  type: item.scheduleType,
                                  value: item.name,
                                );

                                await CurrentScheduleStorage.save(target);

                                if (!mounted) return;

                                setState(() {
                                  _activeType = item.scheduleType.name;
                                  _activeValue = item.name;
                                });

                                messenger.showSnackBar(
                                  SnackBar(
                                    content: Text('Выбрано: ${item.name}'),
                                  ),
                                );

                                widget.onScheduleChanged?.call();
                              },
                              onLongPress: () => _confirmDelete(item),
                            );
                          },
                        ),
                        if (_canScrollLeft)
                          Positioned(
                            left: 0,
                            top: 0,
                            bottom: 0,
                            child: IgnorePointer(
                              child: _EdgeHint(direction: AxisDirection.left),
                            ),
                          ),
                        if (_canScrollRight)
                          Positioned(
                            right: 0,
                            top: 0,
                            bottom: 0,
                            child: IgnorePointer(
                              child: _EdgeHint(direction: AxisDirection.right),
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  if (favorites.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(
                      'Долгое нажатие — удалить',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Colors.black54,
                      ),
                    ),
                  ],
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _FavoriteChip extends StatelessWidget {
  final FavoriteItem item;
  final bool isActive;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;

  const _FavoriteChip({
    required this.item,
    required this.isActive,
    required this.onTap,
    this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    final icon = item.scheduleType == ScheduleType.group
        ? Icons.group
        : item.scheduleType == ScheduleType.teacher
        ? Icons.person
        : Icons.location_on;

    final bg = isActive
        ? Colors.green.withValues(alpha: 0.15)
        : Colors.grey.withValues(alpha: 0.12);

    final border = isActive ? Colors.green : Colors.transparent;

    return InkWell(
      borderRadius: BorderRadius.circular(999),
      onTap: onTap,
      onLongPress: onLongPress,
      child: Container(
        constraints: const BoxConstraints(minWidth: 120),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: border, width: 1.2),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 18, color: isActive ? Colors.green : Colors.black54),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                item.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
                ),
              ),
            ),
            if (isActive) ...[
              const SizedBox(width: 6),
              const Icon(Icons.check_circle, size: 16, color: Colors.green),
            ],
          ],
        ),
      ),
    );
  }
}

class _AddChip extends StatelessWidget {
  final VoidCallback onTap;

  const _AddChip({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(999),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.grey.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(999),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.add, size: 18),
            SizedBox(width: 6),
            Text('Добавить'),
          ],
        ),
      ),
    );
  }
}

class _EdgeHint extends StatelessWidget {
  final AxisDirection direction;

  const _EdgeHint({required this.direction});

  @override
  Widget build(BuildContext context) {
    final isLeft = direction == AxisDirection.left;

    return Container(
      width: 34,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: isLeft ? Alignment.centerLeft : Alignment.centerRight,
          end: isLeft ? Alignment.centerRight : Alignment.centerLeft,
          colors: [
            Colors.white,
            Colors.white.withValues(alpha: 0.0),
          ],
        ),
      ),
      child: Align(
        alignment: isLeft ? Alignment.centerLeft : Alignment.centerRight,
        child: Icon(
          isLeft ? Icons.chevron_left : Icons.chevron_right,
          color: Colors.black38,
        ),
      ),
    );
  }
}
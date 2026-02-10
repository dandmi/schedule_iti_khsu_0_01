import 'package:flutter/material.dart';
import 'package:schedule_iti_khsu_0_01/api/api_client.dart';
import 'package:schedule_iti_khsu_0_01/database/database_helper.dart';
import 'package:schedule_iti_khsu_0_01/utils/schedule_type.dart';

class _SuggestionItem {
  final ScheduleType type;
  final String value;

  const _SuggestionItem({
    required this.type,
    required this.value,
  });
}

class AddFavoriteScreen extends StatefulWidget {
  const AddFavoriteScreen({super.key});

  @override
  State<AddFavoriteScreen> createState() => _AddFavoriteScreenState();
}

class _AddFavoriteScreenState extends State<AddFavoriteScreen> {
  final ApiClient _apiClient = ApiClient();
  final DatabaseHelper _db = DatabaseHelper();
  final TextEditingController _searchController = TextEditingController();

  int _requestId = 0;
  bool _isLoading = false;

  List<_SuggestionItem> _groups = [];
  List<_SuggestionItem> _teachers = [];
  List<_SuggestionItem> _auditories = [];

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  IconData _iconFor(ScheduleType type) => switch (type) {
    ScheduleType.group => Icons.group,
    ScheduleType.teacher => Icons.person,
    ScheduleType.auditory => Icons.location_on,
  };

  String _titleFor(ScheduleType type) => switch (type) {
    ScheduleType.group => 'Группы',
    ScheduleType.teacher => 'Преподаватели',
    ScheduleType.auditory => 'Аудитории',
  };

  Future<void> _performSearch(String query) async {
    final messenger = ScaffoldMessenger.of(context); // берём ДО await
    final q = query.trim();

    if (q.isEmpty) {
      if (!mounted) return;
      setState(() {
        _groups = [];
        _teachers = [];
        _auditories = [];
        _isLoading = false;
      });
      return;
    }

    final currentRequest = ++_requestId;

    if (!mounted) return;
    setState(() => _isLoading = true);

    try {
      final result = await _apiClient.search(q);

      if (!mounted || currentRequest != _requestId) return;

      // courses игнорируем полностью
      List<_SuggestionItem> groups =
      result.names.map((s) => _SuggestionItem(type: ScheduleType.group, value: s)).toList();
      List<_SuggestionItem> teachers = result.teacherNames
          .map((s) => _SuggestionItem(type: ScheduleType.teacher, value: s))
          .toList();
      List<_SuggestionItem> auds =
      result.auditories.map((s) => _SuggestionItem(type: ScheduleType.auditory, value: s)).toList();

      // чистка: trim + remove empty + remove duplicates (внутри каждой секции)
      groups = _cleanSection(groups);
      teachers = _cleanSection(teachers);
      auds = _cleanSection(auds);

      setState(() {
        _groups = groups;
        _teachers = teachers;
        _auditories = auds;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      messenger.showSnackBar(
        SnackBar(content: Text('Ошибка поиска: $e')),
      );
    }
  }

  List<_SuggestionItem> _cleanSection(List<_SuggestionItem> items) {
    final seen = <String>{};
    final out = <_SuggestionItem>[];
    for (final it in items) {
      final v = it.value.trim();
      if (v.isEmpty) continue;
      if (seen.add(v)) out.add(_SuggestionItem(type: it.type, value: v));
    }
    return out;
  }

  Future<void> _addFavorite(_SuggestionItem item) async {
    final navigator = Navigator.of(context); // берём ДО await

    await _db.addFavorite(
      name: item.value,
      type: item.type.name, // group/teacher/auditory
    );

    navigator.pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final hasAny = _groups.isNotEmpty || _teachers.isNotEmpty || _auditories.isNotEmpty;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Добавить в избранное'),
        centerTitle: true,
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 10),
            child: TextField(
              controller: _searchController,
              onChanged: _performSearch,
              decoration: InputDecoration(
                hintText: 'Поиск группы, преподавателя или аудитории...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchController.text.isEmpty
                    ? null
                    : IconButton(
                  icon: const Icon(Icons.clear),
                  onPressed: () {
                    _searchController.clear();
                    _performSearch('');
                  },
                ),
                border: const OutlineInputBorder(),
              ),
            ),
          ),

          if (_isLoading)
            const Padding(
              padding: EdgeInsets.only(top: 8),
              child: LinearProgressIndicator(),
            ),

          Expanded(
            child: !hasAny
                ? const Center(child: Text('Начните вводить запрос'))
                : ListView(
              children: [
                if (_groups.isNotEmpty) ...[
                  _SectionHeader(title: _titleFor(ScheduleType.group)),
                  ..._groups.map((it) => _ResultTile(
                    icon: _iconFor(it.type),
                    title: it.value,
                    badgeText: 'Группа',
                    onTap: () => _addFavorite(it),
                  )),
                  const SizedBox(height: 8),
                ],
                if (_teachers.isNotEmpty) ...[
                  _SectionHeader(title: _titleFor(ScheduleType.teacher)),
                  ..._teachers.map((it) => _ResultTile(
                    icon: _iconFor(it.type),
                    title: it.value,
                    badgeText: 'Преподаватель',
                    onTap: () => _addFavorite(it),
                  )),
                  const SizedBox(height: 8),
                ],
                if (_auditories.isNotEmpty) ...[
                  _SectionHeader(title: _titleFor(ScheduleType.auditory)),
                  ..._auditories.map((it) => _ResultTile(
                    icon: _iconFor(it.type),
                    title: it.value,
                    badgeText: 'Аудитория',
                    onTap: () => _addFavorite(it),
                  )),
                  const SizedBox(height: 8),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: Text(
        title,
        style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
      ),
    );
  }
}

class _ResultTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String badgeText;
  final VoidCallback onTap;

  const _ResultTile({
    required this.icon,
    required this.title,
    required this.badgeText,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon),
      title: Text(title),
      trailing: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.grey.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(
          badgeText,
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ),
      onTap: onTap,
    );
  }
}

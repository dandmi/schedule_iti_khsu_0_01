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

  List<String> _buildSearchVariants(String query) {
    final variants = <String>[];
    final seen = <String>{};

    void addVariant(String value) {
      final trimmed = value.trim();
      if (trimmed.isEmpty) return;
      if (seen.add(trimmed)) {
        variants.add(trimmed);
      }
    }

    addVariant(query);
    addVariant(query.toLowerCase());
    addVariant(query.toUpperCase());
    addVariant(_toTitleCase(query));

    return variants;
  }

  String _toTitleCase(String input) {
    final words = input.trim().split(RegExp(r'\s+'));
    final result = <String>[];

    for (final word in words) {
      if (word.isEmpty) continue;

      if (word.length == 1) {
        result.add(word.toUpperCase());
        continue;
      }

      final first = word.substring(0, 1).toUpperCase();
      final rest = word.substring(1).toLowerCase();
      result.add('$first$rest');
    }

    return result.join(' ');
  }

  SearchResponse _mergeSearchResponses(List<SearchResponse> responses) {
    final names = <String>{};
    final teacherNames = <String>{};
    final auditories = <String>{};

    for (final response in responses) {
      names.addAll(response.names.map((e) => e.trim()).where((e) => e.isNotEmpty));
      teacherNames.addAll(
        response.teacherNames.map((e) => e.trim()).where((e) => e.isNotEmpty),
      );
      auditories.addAll(
        response.auditories.map((e) => e.trim()).where((e) => e.isNotEmpty),
      );
    }

    return SearchResponse(
      names: names.toList(),
      courses: const [],
      teacherNames: teacherNames.toList(),
      auditories: auditories.toList(),
    );
  }

  Future<SearchResponse> _searchIgnoringCase(String query) async {
    final variants = _buildSearchVariants(query);

    final responses = <SearchResponse>[];
    for (final variant in variants) {
      try {
        final response = await _apiClient.search(variant);
        responses.add(response);
      } catch (_) {
        // Один вариант может не сработать — продолжаем с другими
      }
    }

    if (responses.isEmpty) {
      throw Exception('Не удалось выполнить поиск');
    }

    return _mergeSearchResponses(responses);
  }

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
      final result = await _searchIgnoringCase(q);

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

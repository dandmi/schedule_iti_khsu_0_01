import 'package:flutter/material.dart';

import '../database/database_helper.dart';
import '../models/note.dart';
import '../utils/app_refresh_bus.dart';
import '../utils/local_notification_service.dart';
import 'note_edit_screen.dart';

class NotesScreen extends StatefulWidget {
  const NotesScreen({super.key});

  @override
  State<NotesScreen> createState() => NotesScreenState();
}

class NotesScreenState extends State<NotesScreen> {
  final _db = DatabaseHelper();

  @override
  void initState() {
    super.initState();
    AppRefreshBus.notesVersion.addListener(_onExternalNotesChanged);
  }

  @override
  void dispose() {
    AppRefreshBus.notesVersion.removeListener(_onExternalNotesChanged);
    super.dispose();
  }

  Future<void> reload() async => _reload();

  Future<void> openCreate() async => _openCreate();

  void _onExternalNotesChanged() {
    _reload();
  }

  void _reload() {
    if (!mounted) return;
    setState(() {});
  }

  Future<void> _openCreate() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const NoteEditScreen()),
    );
    _reload();
  }

  Future<void> _openEdit(Note note) async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => NoteEditScreen(note: note)),
    );
    _reload();
  }

  Future<void> _delete(Note note) async {
    if (note.id == null) return;

    final title = (note.title ?? '').trim();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Удалить заметку?'),
          content: Text(
            title.isEmpty
                ? 'Заметка будет удалена без возможности восстановления.'
                : 'Заметка «$title» будет удалена без возможности восстановления.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Отмена'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              style: TextButton.styleFrom(
                foregroundColor: Theme.of(dialogContext).colorScheme.error,
              ),
              child: const Text('Удалить'),
            ),
          ],
        );
      },
    );

    if (confirmed != true || !mounted) return;

    await _db.deleteNote(note.id!);

    try {
      await LocalNotificationService.instance.rescheduleAll();
    } catch (_) {}

    AppRefreshBus.markNotesChanged();
    AppRefreshBus.markScheduleChanged();

    _reload();
  }

  String _two(int value) => value.toString().padLeft(2, '0');

  String _formatDateTime(int millis) {
    final dt = DateTime.fromMillisecondsSinceEpoch(millis);
    return '${_two(dt.day)}.${_two(dt.month)}.${dt.year} ${_two(dt.hour)}:${_two(dt.minute)}';
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return FutureBuilder<List<Note>>(
      future: _db.getNotes(),
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snap.hasError) {
          return Center(child: Text('Ошибка: ${snap.error}'));
        }

        final notes = snap.data ?? [];

        if (notes.isEmpty) {
          return const Center(
            child: Text('Пока нет заметок. Нажми "+" чтобы добавить.'),
          );
        }

        return ListView.separated(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
          itemCount: notes.length,
          separatorBuilder: (_, __) => const SizedBox(height: 10),
          itemBuilder: (context, i) {
            final n = notes[i];

            final title =
            (n.title ?? '').trim().isEmpty ? '(без названия)' : n.title!.trim();

            final desc = (n.description ?? '').trim();
            final subject = (n.subject ?? '').trim();
            final dueText =
            n.dueAt != null ? 'Срок: ${_formatDateTime(n.dueAt!)}' : '';

            final subtitleParts = <String>[];
            if (subject.isNotEmpty) subtitleParts.add('Предмет: $subject');
            if (desc.isNotEmpty) subtitleParts.add(desc);
            if (dueText.isNotEmpty) subtitleParts.add(dueText);

            return Card(
              margin: EdgeInsets.zero,
              child: ListTile(
                contentPadding: const EdgeInsets.fromLTRB(14, 10, 8, 10),
                title: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: scheme.onSurface,
                  ),
                ),
                subtitle: subtitleParts.isEmpty
                    ? null
                    : Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    subtitleParts.join('\n'),
                    maxLines: 4,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ),
                trailing: IconButton(
                  tooltip: 'Удалить',
                  color: scheme.onSurfaceVariant,
                  icon: const Icon(Icons.delete_outline),
                  onPressed: () => _delete(n),
                ),
                onTap: () => _openEdit(n),
              ),
            );
          },
        );
      },
    );
  }
}

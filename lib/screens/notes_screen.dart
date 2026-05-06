import 'package:flutter/material.dart';
import '../database/database_helper.dart';
import '../models/note.dart';
import 'note_edit_screen.dart';
import '../utils/local_notification_service.dart';
import '../utils/app_refresh_bus.dart';

class NotesScreen extends StatefulWidget {
  const NotesScreen({super.key});

  @override
  State<NotesScreen> createState() => NotesScreenState();
}

class NotesScreenState extends State<NotesScreen> {
  final _db = DatabaseHelper();

  void _reload() {
    if (!mounted) return;
    setState(() {});
  }

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

  void _onExternalNotesChanged() {
    _reload();
  }

  Future<void> reload() async => _reload();

  String _two(int value) => value.toString().padLeft(2, '0');

  String _formatDateTime(int millis) {
    final dt = DateTime.fromMillisecondsSinceEpoch(millis);
    return '${_two(dt.day)}.${_two(dt.month)}.${dt.year} ${_two(dt.hour)}:${_two(dt.minute)}';
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

    await _db.deleteNote(note.id!);

    try {
      await LocalNotificationService.instance.rescheduleAll();
    } catch (e, stack) {
      debugPrint('❌ Failed to reschedule after delete: $e\n$stack');
    }

    AppRefreshBus.markNotesChanged();
    AppRefreshBus.markScheduleChanged();

    _reload();
  }

  Future<void> openCreate() async => _openCreate();

  @override
  Widget build(BuildContext context) {
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
          itemCount: notes.length,
          separatorBuilder: (_, __) => const Divider(height: 1),
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

            return ListTile(
              title: Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              subtitle: subtitleParts.isEmpty
                  ? null
                  : Text(
                subtitleParts.join('\n'),
                maxLines: 4,
                overflow: TextOverflow.ellipsis,
              ),
              onTap: () => _openEdit(n),
              trailing: IconButton(
                icon: const Icon(Icons.delete_outline),
                onPressed: () => _delete(n),
              ),
            );
          },
        );
      },
    );
  }
}
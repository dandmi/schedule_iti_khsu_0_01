import 'package:flutter/material.dart';

import '../database/database_helper.dart';
import '../models/note.dart';
import 'note_edit_screen.dart';

class NotesScreen extends StatefulWidget {
  const NotesScreen({super.key});

  @override
  State<NotesScreen> createState() => NotesScreenState();
}

class NotesScreenState extends State<NotesScreen> {
  final _db = DatabaseHelper();

  void _reload() {
    if (!mounted) return;
    setState(() {}); // ✅ просто перерисовать -> FutureBuilder заново вызовет getNotes()
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
    _reload();
  }

  // Если HomeScreen дергает этот метод для FAB — он остаётся
  Future<void> openCreate() async => _openCreate();

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Note>>(
      future: _db.getNotes(), // ✅ новый Future при каждом build
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

            return ListTile(
              title: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis),
              subtitle: desc.isEmpty
                  ? null
                  : Text(desc, maxLines: 2, overflow: TextOverflow.ellipsis),
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

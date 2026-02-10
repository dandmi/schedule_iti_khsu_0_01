import 'package:flutter/material.dart';
import '../database/database_helper.dart';
import '../models/note.dart';

class NoteEditScreen extends StatefulWidget {
  final Note? note;
  final int? lessonId;

  const NoteEditScreen({super.key, this.note, this.lessonId});

  @override
  State<NoteEditScreen> createState() => _NoteEditScreenState();
}

class _NoteEditScreenState extends State<NoteEditScreen> {
  final _db = DatabaseHelper();
  final _titleCtrl = TextEditingController();
  final _descCtrl = TextEditingController();

  bool get _isEdit => widget.note?.id != null;

  @override
  void initState() {
    super.initState();
    _titleCtrl.text = widget.note?.title ?? '';
    _descCtrl.text = widget.note?.description ?? '';
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final title = _titleCtrl.text.trim();
    final desc = _descCtrl.text.trim();

    if (_isEdit) {
      await _db.updateNote(
        noteId: widget.note!.id!,
        title: title,
        description: desc,
      );
    } else {
      await _db.addNote(
        title: title,
        description: desc,
        lessonId: widget.lessonId,
      );
    }

    if (!mounted) return;
    Navigator.pop(context, true); // сообщаем списку: было изменение
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEdit ? 'Редактирование' : 'Новая заметка'),
        actions: [
          IconButton(
            icon: const Icon(Icons.save),
            onPressed: _save,
          )
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(
              controller: _titleCtrl,
              decoration: const InputDecoration(
                labelText: 'Заголовок',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: TextField(
                controller: _descCtrl,
                maxLines: null,
                expands: true,
                decoration: const InputDecoration(
                  labelText: 'Описание',
                  border: OutlineInputBorder(),
                  alignLabelWithHint: true,
                ),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _save,
                icon: const Icon(Icons.check),
                label: const Text('Сохранить'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

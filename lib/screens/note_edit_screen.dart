import 'package:flutter/material.dart';
import '../database/database_helper.dart';
import '../models/note.dart';
import '../utils/local_notification_service.dart';

class NoteEditScreen extends StatefulWidget {
  final Note? note;
  final int? lessonId;
  final String? initialSubject;

  const NoteEditScreen({
    super.key,
    this.note,
    this.lessonId,
    this.initialSubject,
  });

  @override
  State<NoteEditScreen> createState() => _NoteEditScreenState();
}

class _NoteEditScreenState extends State<NoteEditScreen> {
  final _db = DatabaseHelper();

  final _titleCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _subjectCtrl = TextEditingController();

  bool _hasDueDate = false;
  DateTime? _dueAt;

  bool get _isEdit => widget.note?.id != null;

  @override
  void initState() {
    super.initState();

    _titleCtrl.text = widget.note?.title ?? '';
    _descCtrl.text = widget.note?.description ?? '';
    _subjectCtrl.text = widget.note?.subject ?? widget.initialSubject ?? '';

    final dueAtMillis = widget.note?.dueAt;
    if (dueAtMillis != null) {
      _hasDueDate = true;
      _dueAt = DateTime.fromMillisecondsSinceEpoch(dueAtMillis);
    }
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _descCtrl.dispose();
    _subjectCtrl.dispose();
    super.dispose();
  }

  String _two(int value) => value.toString().padLeft(2, '0');

  String _formatDateTime(DateTime dt) {
    return '${_two(dt.day)}.${_two(dt.month)}.${dt.year} ${_two(dt.hour)}:${_two(dt.minute)}';
  }

  Future<void> _pickDueDateTime() async {
    final now = DateTime.now();
    final initial = _dueAt ?? now.add(const Duration(days: 1));

    final pickedDate = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 10),
    );

    if (pickedDate == null || !mounted) return;

    final pickedTime = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(initial),
    );

    if (!mounted) return;

    final time = pickedTime ?? const TimeOfDay(hour: 23, minute: 59);

    setState(() {
      _hasDueDate = true;
      _dueAt = DateTime(
        pickedDate.year,
        pickedDate.month,
        pickedDate.day,
        time.hour,
        time.minute,
      );
    });
  }

  Future<void> _save() async {
    final title = _titleCtrl.text.trim();
    final desc = _descCtrl.text.trim();
    final subject = _subjectCtrl.text.trim();
    final dueAtMillis = _hasDueDate ? _dueAt?.millisecondsSinceEpoch : null;

    if (_isEdit) {
      await _db.updateNote(
        noteId: widget.note!.id!,
        title: title,
        description: desc,
        subject: subject,
        dueAt: dueAtMillis,
        lessonId: widget.note!.lessonId ?? widget.lessonId,
      );
    } else {
      await _db.addNote(
        title: title,
        description: desc,
        subject: subject,
        dueAt: dueAtMillis,
        lessonId: widget.lessonId,
      );
    }

    try {
      await LocalNotificationService.instance.rescheduleAll();
    } catch (e, stack) {
      debugPrint('❌ Failed to reschedule after save: $e\n$stack');
    }

    if (!mounted) return;
    Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    final dueText = _hasDueDate && _dueAt != null
        ? _formatDateTime(_dueAt!)
        : 'Срок не выбран';

    return Scaffold(
      appBar: AppBar(
        title: Text(_isEdit ? 'Редактирование заметки' : 'Новая заметка'),
        actions: [
          IconButton(
            icon: const Icon(Icons.save),
            onPressed: _save,
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(
            controller: _titleCtrl,
            decoration: const InputDecoration(
              labelText: 'Заголовок',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _subjectCtrl,
            decoration: const InputDecoration(
              labelText: 'Предмет',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _descCtrl,
            minLines: 6,
            maxLines: 12,
            decoration: const InputDecoration(
              labelText: 'Описание',
              border: OutlineInputBorder(),
              alignLabelWithHint: true,
            ),
          ),
          const SizedBox(height: 16),
          SwitchListTile.adaptive(
            contentPadding: EdgeInsets.zero,
            value: _hasDueDate,
            title: const Text('Указать срок сдачи'),
            subtitle: Text(dueText),
            onChanged: (value) {
              setState(() {
                _hasDueDate = value;
                if (!value) {
                  _dueAt = null;
                } else {
                  _dueAt ??= DateTime.now().add(const Duration(days: 1));
                }
              });
            },
          ),
          if (_hasDueDate) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _pickDueDateTime,
                    icon: const Icon(Icons.calendar_today),
                    label: const Text('Выбрать дату и время'),
                  ),
                ),
              ],
            ),
            if (_dueAt != null) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Выбранный срок: ${_formatDateTime(_dueAt!)}',
                    ),
                  ),
                  IconButton(
                    tooltip: 'Очистить срок',
                    onPressed: () {
                      setState(() {
                        _hasDueDate = false;
                        _dueAt = null;
                      });
                    },
                    icon: const Icon(Icons.clear),
                  ),
                ],
              ),
            ],
          ],
          const SizedBox(height: 20),
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
    );
  }
}
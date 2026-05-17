import 'dart:convert';

import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import 'package:synchronized/synchronized.dart';

import '../models/favorite_item.dart';
import '../models/lesson.dart';
import '../models/note.dart';
import '../models/upcoming_lesson_reminder.dart';

class DatabaseHelper {
  static final DatabaseHelper _instance = DatabaseHelper._internal();
  static Database? _database;
  static final _lock = Lock();

  factory DatabaseHelper() => _instance;

  DatabaseHelper._internal();

  Future<Database> get database async {
    final existing = _database;
    if (existing != null) return existing;

    await _lock.synchronized(() async {
      _database ??= await _initDatabase();
    });

    return _database!;
  }

  Future<Database> _initDatabase() async {
    final path = join(await getDatabasesPath(), 'schedule_v3.db');

    return openDatabase(
      path,
      version: 1,
      onCreate: _onCreate,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE time_slot (
        slot_id INTEGER PRIMARY KEY,
        start_time TEXT NOT NULL,
        end_time TEXT NOT NULL
      )
    ''');

    await _insertDefaultTimeSlots(db);

    await db.execute('''
      CREATE TABLE lesson (
        lesson_id INTEGER PRIMARY KEY,
        date TEXT NOT NULL,
        weekday INTEGER NOT NULL,
        slot_id INTEGER NOT NULL,
        subject TEXT NOT NULL,
        teacher TEXT NOT NULL,
        auditory TEXT NOT NULL,
        groups_json TEXT,
        lesson_type TEXT NOT NULL,
        target_type TEXT NOT NULL,
        target_value TEXT NOT NULL,
        UNIQUE(date, slot_id, target_type, target_value) ON CONFLICT REPLACE
      )
    ''');

    // Снимок нужен, чтобы отличать «занятий нет» от «день ещё не загружался».
    await db.execute('''
      CREATE TABLE schedule_snapshot (
        snapshot_id INTEGER PRIMARY KEY AUTOINCREMENT,
        date TEXT NOT NULL,
        target_type TEXT NOT NULL,
        target_value TEXT NOT NULL,
        has_data INTEGER NOT NULL,
        synced_at INTEGER NOT NULL,
        UNIQUE(date, target_type, target_value) ON CONFLICT REPLACE
      )
    ''');

    await db.execute('''
      CREATE TABLE favorite (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        type TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE note (
        note_id INTEGER PRIMARY KEY AUTOINCREMENT,
        title TEXT,
        description TEXT,
        subject TEXT,
        created_at INTEGER NOT NULL,
        due_at INTEGER
      )
    ''');
  }

  Future<void> saveSchedule({
    required String date,
    required int weekday,
    required List<Lesson> lessons,
    required String targetType,
    required String targetValue,
  }) async {
    final db = await database;

    await db.delete(
      'lesson',
      where: 'date = ? AND target_type = ? AND target_value = ?',
      whereArgs: [date, targetType, targetValue],
    );

    for (final lesson in lessons) {
      await db.insert('lesson', {
        'date': date,
        'weekday': weekday,
        'slot_id': lesson.time,
        'subject': lesson.subject,
        'teacher': lesson.teacher,
        'auditory': lesson.auditory,
        'groups_json': jsonEncode(lesson.group),
        'lesson_type': lesson.typeLesson,
        'target_type': targetType,
        'target_value': targetValue,
      });
    }

    await db.insert(
      'schedule_snapshot',
      {
        'date': date,
        'target_type': targetType,
        'target_value': targetValue,
        'has_data': lessons.isNotEmpty ? 1 : 0,
        'synced_at': DateTime.now().millisecondsSinceEpoch,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<Lesson>> getSchedule({
    required String date,
    required String targetType,
    required String targetValue,
  }) async {
    final db = await database;
    final maps = await db.query(
      'lesson',
      where: 'date = ? AND target_type = ? AND target_value = ?',
      whereArgs: [date, targetType, targetValue],
      orderBy: 'slot_id',
    );

    return maps.map((e) => Lesson.fromMap(e)).toList();
  }

  Future<Map<int, ({String start, String end})>> getTimeSlots() async {
    final db = await database;
    final maps = await db.query('time_slot');

    final out = <int, ({String start, String end})>{};
    for (final row in maps) {
      final id = row['slot_id'] as int;
      out[id] = (
        start: row['start_time'] as String,
        end: row['end_time'] as String,
      );
    }

    return out;
  }

  Future<bool> hasScheduleSnapshot({
    required String date,
    required String targetType,
    required String targetValue,
  }) async {
    final db = await database;

    final maps = await db.query(
      'schedule_snapshot',
      columns: ['snapshot_id'],
      where: 'date = ? AND target_type = ? AND target_value = ?',
      whereArgs: [date, targetType, targetValue],
      limit: 1,
    );

    return maps.isNotEmpty;
  }

  Future<List<FavoriteItem>> getFavorites() async {
    final db = await database;
    final maps = await db.query(
      'favorite',
      orderBy: 'id DESC',
    );

    return maps.map((e) => FavoriteItem.fromMap(e)).toList();
  }

  Future<void> addFavorite({required String name, required String type}) async {
    final db = await database;

    final exists = await db.query(
      'favorite',
      where: 'name = ? AND type = ?',
      whereArgs: [name, type],
      limit: 1,
    );

    if (exists.isEmpty) {
      await db.insert('favorite', {'name': name, 'type': type});
    }
  }

  Future<void> removeFavorite(int id) async {
    final db = await database;
    await db.delete('favorite', where: 'id = ?', whereArgs: [id]);
  }

  Future<List<Note>> getNotes() async {
    final db = await database;

    final maps = await db.rawQuery('''
      SELECT *
      FROM note
      ORDER BY
        CASE WHEN due_at IS NULL THEN 1 ELSE 0 END,
        due_at ASC,
        created_at DESC
    ''');

    return maps.map((e) => Note.fromMap(e)).toList();
  }

  Future<int> addNote({
    String? title,
    String? description,
    String? subject,
    int? dueAt,
  }) async {
    final db = await database;

    return db.insert(
      'note',
      {
        'title': title,
        'description': description,
        'subject': subject,
        'created_at': DateTime.now().millisecondsSinceEpoch,
        'due_at': dueAt,
      },
      conflictAlgorithm: ConflictAlgorithm.abort,
    );
  }

  Future<int> updateNote({
    required int noteId,
    String? title,
    String? description,
    String? subject,
    int? dueAt,
  }) async {
    final db = await database;

    return db.update(
      'note',
      {
        'title': title,
        'description': description,
        'subject': subject,
        'due_at': dueAt,
      },
      where: 'note_id = ?',
      whereArgs: [noteId],
    );
  }

  Future<int> deleteNote(int noteId) async {
    final db = await database;

    return db.delete(
      'note',
      where: 'note_id = ?',
      whereArgs: [noteId],
    );
  }

  Future<List<Note>> getNotesWithDueAt() async {
    final db = await database;

    final maps = await db.query(
      'note',
      where: 'due_at IS NOT NULL',
      orderBy: 'due_at ASC',
    );

    return maps.map((e) => Note.fromMap(e)).toList();
  }

  Future<List<UpcomingLessonReminder>> getUpcomingLessonsForTarget({
    required String targetType,
    required String targetValue,
    String? fromDate,
  }) async {
    final db = await database;

    final whereBuffer = StringBuffer(
      'l.target_type = ? AND l.target_value = ?',
    );
    final args = <Object?>[targetType, targetValue];

    if (fromDate != null) {
      whereBuffer.write(' AND date(l.date) >= date(?)');
      args.add(fromDate);
    }

    final maps = await db.rawQuery('''
      SELECT
        l.lesson_id,
        l.subject,
        l.teacher,
        l.auditory,
        l.groups_json,
        l.date,
        t.start_time,
        l.target_type,
        l.target_value
      FROM lesson l
      INNER JOIN time_slot t ON t.slot_id = l.slot_id
      WHERE ${whereBuffer.toString()}
      ORDER BY l.date ASC, l.slot_id ASC
    ''', args);

    return maps.map((e) => UpcomingLessonReminder.fromMap(e)).toList();
  }

  Future<void> _insertDefaultTimeSlots(Database db) async {
    final slots = [
      {'id': 1, 'start': '08:00', 'end': '09:30'},
      {'id': 2, 'start': '09:50', 'end': '11:20'},
      {'id': 3, 'start': '11:40', 'end': '13:10'},
      {'id': 4, 'start': '13:40', 'end': '15:10'},
      {'id': 5, 'start': '15:20', 'end': '16:50'},
      {'id': 6, 'start': '17:00', 'end': '18:30'},
      {'id': 7, 'start': '18:40', 'end': '20:10'},
    ];

    for (final slot in slots) {
      await db.insert(
        'time_slot',
        {
          'slot_id': slot['id'],
          'start_time': slot['start'],
          'end_time': slot['end'],
        },
        conflictAlgorithm: ConflictAlgorithm.ignore,
      );
    }
  }

  Future<void> clearDownloadedSchedules() async {
    final db = await database;

    await db.delete('lesson');
    await db.delete('schedule_snapshot');

    await db.execute('VACUUM');
  }
}

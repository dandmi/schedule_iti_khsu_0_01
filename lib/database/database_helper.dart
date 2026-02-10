import 'dart:convert';

import 'package:flutter/cupertino.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:schedule_iti_khsu_0_01/models/lesson.dart';

import '../models/favorite_item.dart';
import 'package:synchronized/synchronized.dart';

import '../models/note.dart';

class DatabaseHelper {
  static final DatabaseHelper _instance = DatabaseHelper._internal();
  factory DatabaseHelper() => _instance;
  DatabaseHelper._internal();

  static Database? _database;
  static final _lock = Lock(); // ← добавь это

  Future<Database> get database async {
    if (_database != null) return _database!;
    // ← защищаем инициализацию
    await _lock.synchronized(() async {
      if (_database == null) {
        _database = await _initDatabase();
      }
    });
    return _database!;
  }

  Future<Database> _initDatabase() async {
    try {
      final String path = join(await getDatabasesPath(), 'schedule.db');
      debugPrint('📁 Путь к БД: $path');
      final db = await openDatabase(
        path,
        version: 2,
        onCreate: _onCreate,
        onUpgrade: _onUpgrade,
      );
      debugPrint('✅ БД открыта успешно');
      return db;
    } catch (e, stack) {
      debugPrint('❌ Ошибка инициализации БД: $e\n$stack');
      rethrow;
    }
  }

  Future<void> _onCreate(Database db, int version) async {
    // 1. Временные слоты
    await db.execute('''
      CREATE TABLE time_slot (
        slot_id INTEGER PRIMARY KEY,
        start_time TEXT NOT NULL,  -- "08:30"
        end_time TEXT NOT NULL     -- "10:00"
      )
    ''');

    // Предзаполним типичные слоты (можно позже обновлять через API или настройки)
    await _insertDefaultTimeSlots(db);

    // 2. Занятия
    await db.execute('''
      CREATE TABLE lesson (
        lesson_id INTEGER PRIMARY KEY,
        date TEXT NOT NULL,               -- "2026-02-06"
        weekday INTEGER NOT NULL,         -- 1=пн, ..., 7=вс
        slot_id INTEGER NOT NULL,         -- ссылка на time_slot
        subject TEXT NOT NULL,
        teacher TEXT NOT NULL,
        auditory TEXT NOT NULL,
        groups_json TEXT,  -- будет хранить '["М-124-1", "С-25"]'
        lesson_type TEXT NOT NULL,        -- "л.", "пр.", "лаб."
        target_type TEXT NOT NULL,        -- "group", "teacher", или "auditory"
        target_value TEXT NOT NULL,       -- например: "М-124-1", "Заливаха А.В.", "2-423"
        UNIQUE(date, slot_id, target_type, target_value) ON CONFLICT REPLACE
      )
    ''');

    // 3. Избранные
    await db.execute('''
      CREATE TABLE favorite (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,               -- "М-124-1", "Заливаха А.В.", "2-423"
        type TEXT NOT NULL                -- "group", "teacher", "auditory"
      )
    ''');

    // 4. Заметки
    await db.execute('''
      CREATE TABLE note (
        note_id INTEGER PRIMARY KEY AUTOINCREMENT,
        title TEXT,
        description TEXT,
        created_at INTEGER NOT NULL,      -- timestamp
        lesson_id INTEGER,
        FOREIGN KEY (lesson_id) REFERENCES lesson (lesson_id) ON DELETE CASCADE
      )
    ''');
  }

  Future<void> _insertDefaultTimeSlots(Database db) async {
    // Пример для твоего института — адаптируй под реальное расписание
    final slots = [
      {'id': 1, 'start': '08:00', 'end': '09:30'},
      {'id': 2, 'start': '09:50', 'end': '11:20'},
      {'id': 3, 'start': '11:40', 'end': '13:10'},
      {'id': 4, 'start': '13:40', 'end': '15:10'},
      {'id': 5, 'start': '15:20', 'end': '16:50'},
      {'id': 6, 'start': '17:00', 'end': '18:30'}, // как в твоём JSON
      {'id': 7, 'start': '18:40', 'end': '20:10'},
    ];

    for (var slot in slots) {
      await db.insert('time_slot', {
        'slot_id': slot['id'],
        'start_time': slot['start'],
        'end_time': slot['end'],
      }, conflictAlgorithm: ConflictAlgorithm.ignore);
    }
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    // Пример: если oldVersion < 2 — добавить таблицу favorite и изменить lesson
    if (oldVersion < 2) {
      // Здесь можно реализовать миграцию от старой схемы
      // Но для MVP проще удалить и создать заново (если данные не критичны)
      // Или оставить как есть — у тебя первая версия
    }
  }

  // В классе DatabaseHelper

  Future<void> saveSchedule({
    required String date, // формат: '2026-02-06'
    required int weekday,
    required List<Lesson> lessons,
    required String targetType,
    required String targetValue,
  }) async {
    final db = await database;

    // Удалим старые занятия для этой даты и цели (чтобы избежать дублей)
    await db.delete(
      'lesson',
      where: 'date = ? AND target_type = ? AND target_value = ?',
      whereArgs: [date, targetType, targetValue],
    );

    // Вставим новые
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
  }

  Future<List<Lesson>> getSchedule({
    required String date,
    required String targetType,
    required String targetValue,
  }) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'lesson',
      where: 'date = ? AND target_type = ? AND target_value = ?',
      whereArgs: [date, targetType, targetValue],
      orderBy: 'slot_id',
    );

    return maps.map((e) => Lesson.fromMap(e)).toList();
  }

  // Получить все избранные
  Future<List<FavoriteItem>> getFavorites() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'favorite',
      orderBy: 'id DESC', // последние сверху
    );
    return maps.map((e) => FavoriteItem.fromMap(e)).toList();
  }

// Добавить в избранное
  Future<void> addFavorite({required String name, required String type}) async {
    final db = await database;
    // Проверим дубликат
    final exists = await db.query(
      'favorite',
      where: 'name = ? AND type = ?',
      whereArgs: [name, type],
    );
    if (exists.isEmpty) {
      await db.insert('favorite', {'name': name, 'type': type});
    }
  }

// Удалить из избранного
  Future<void> removeFavorite(int id) async {
    final db = await database;
    await db.delete('favorite', where: 'id = ?', whereArgs: [id]);
  }

  Future<List<String>> getFavoritesByType(String type) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'favorite',
      where: 'type = ?',
      whereArgs: [type],
      orderBy: 'name',
    );
    return maps.map((row) => row['name'] as String).toList();
  }



  // ===== NOTES =====

  Future<int> addNote({
    String? title,
    String? description,
    int? lessonId,
  }) async {
    final db = await database;
    return db.insert('note', {
      'title': title,
      'description': description,
      'created_at': DateTime.now().millisecondsSinceEpoch,
      'lesson_id': lessonId,
    });
  }

  Future<int> updateNote({
    required int noteId,
    String? title,
    String? description,
  }) async {
    final db = await database;
    return db.update(
      'note',
      {
        'title': title,
        'description': description,
      },
      where: 'note_id = ?',
      whereArgs: [noteId],
    );
  }

  Future<int> deleteNote(int noteId) async {
    final db = await database;
    return db.delete('note', where: 'note_id = ?', whereArgs: [noteId]);
  }

  Future<List<Note>> getNotes({int? lessonId}) async {
    final db = await database;
    final maps = await db.query(
      'note',
      where: lessonId != null ? 'lesson_id = ?' : null,
      whereArgs: lessonId != null ? [lessonId] : null,
      orderBy: 'created_at DESC',
    );
    return maps.map((e) => Note.fromMap(e)).toList();
  }

  Future<Note?> getNoteById(int noteId) async {
    final db = await database;
    final maps = await db.query(
      'note',
      where: 'note_id = ?',
      whereArgs: [noteId],
      limit: 1,
    );
    if (maps.isEmpty) return null;
    return Note.fromMap(maps.first);
  }

}
import 'dart:async';
import 'package:flutter/services.dart' show rootBundle;
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import 'package:wordcard_coach/core/database/models/word.dart';

class DatabaseHelper {
  static final DatabaseHelper _instance = DatabaseHelper._internal();
  static Database? _database;

  factory DatabaseHelper() => _instance;

  DatabaseHelper._internal();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB();
    return _database!;
  }

  Future<Database> _initDB() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'wordcard_coach.db');

    return await openDatabase(
      path,
      version: 1,
      onCreate: _createDB,
      onOpen: _onOpen,
    );
  }

  Future<void> _createDB(Database db, int version) async {
    // 1. Words table
    await db.execute('''
      CREATE TABLE words (
        id TEXT PRIMARY KEY NOT NULL,
        text TEXT NOT NULL,
        meaning TEXT NOT NULL,
        phonetic TEXT NOT NULL,
        grade INTEGER NOT NULL,
        semester INTEGER NOT NULL,
        unit TEXT NOT NULL,
        difficulty INTEGER NOT NULL,
        category TEXT NOT NULL
      )
    ''');
    await db.execute('CREATE INDEX idx_words_grade_semester ON words(grade, semester)');
    await db.execute('CREATE INDEX idx_words_unit ON words(unit)');
    await db.execute('CREATE INDEX idx_words_category ON words(category)');
    await db.execute('CREATE INDEX idx_words_text ON words(text)');

    // 2. Sentences table
    await db.execute('''
      CREATE TABLE sentences (
        id TEXT PRIMARY KEY NOT NULL,
        text TEXT NOT NULL,
        translation TEXT NOT NULL,
        category TEXT NOT NULL,
        difficulty INTEGER NOT NULL
      )
    ''');
    await db.execute('CREATE INDEX idx_sentences_category ON sentences(category)');

    // 3. WordSentenceMap table
    await db.execute('''
      CREATE TABLE word_sentence_map (
        word_id TEXT NOT NULL,
        sentence_id TEXT NOT NULL,
        is_primary INTEGER NOT NULL DEFAULT 1,
        word_position INTEGER NOT NULL,
        PRIMARY KEY (word_id, sentence_id),
        FOREIGN KEY (word_id) REFERENCES words(id) ON DELETE CASCADE,
        FOREIGN KEY (sentence_id) REFERENCES sentences(id) ON DELETE CASCADE
      )
    ''');
    await db.execute('CREATE INDEX idx_wsm_word ON word_sentence_map(word_id)');
    await db.execute('CREATE INDEX idx_wsm_sentence ON word_sentence_map(sentence_id)');
    await db.execute('CREATE INDEX idx_wsm_primary ON word_sentence_map(word_id, is_primary)');

    // 4. WordProgress table
    await db.execute('''
      CREATE TABLE word_progress (
        id TEXT PRIMARY KEY NOT NULL,
        word_id TEXT NOT NULL,
        easiness_factor REAL NOT NULL DEFAULT 2.5,
        interval INTEGER NOT NULL DEFAULT 1,
        repetition INTEGER NOT NULL DEFAULT 0,
        next_review_date INTEGER NOT NULL DEFAULT 0,
        last_review_date INTEGER NOT NULL DEFAULT 0,
        review_count INTEGER NOT NULL DEFAULT 0,
        correct_count INTEGER NOT NULL DEFAULT 0,
        wrong_count INTEGER NOT NULL DEFAULT 0,
        mastery_level INTEGER NOT NULL DEFAULT 0,
        select_mode_count INTEGER NOT NULL DEFAULT 0,
        spell_mode_count INTEGER NOT NULL DEFAULT 0,
        speak_mode_count INTEGER NOT NULL DEFAULT 0,
        created_at INTEGER NOT NULL,
        updated_at INTEGER NOT NULL,
        FOREIGN KEY (word_id) REFERENCES words(id) ON DELETE CASCADE
      )
    ''');
    await db.execute('CREATE INDEX idx_progress_word ON word_progress(word_id)');
    await db.execute('CREATE INDEX idx_progress_review_date ON word_progress(next_review_date)');
    await db.execute('CREATE INDEX idx_progress_mastery ON word_progress(mastery_level)');

    // 5. UserStats table
    await db.execute('''
      CREATE TABLE user_stats (
        id INTEGER PRIMARY KEY NOT NULL DEFAULT 1,
        nickname TEXT NOT NULL DEFAULT '学习者',
        current_grade INTEGER NOT NULL DEFAULT 3,
        current_semester INTEGER NOT NULL DEFAULT 1,
        total_words_learned INTEGER NOT NULL DEFAULT 0,
        total_words_mastered INTEGER NOT NULL DEFAULT 0,
        total_reviews INTEGER NOT NULL DEFAULT 0,
        total_correct INTEGER NOT NULL DEFAULT 0,
        total_wrong INTEGER NOT NULL DEFAULT 0,
        continuous_days INTEGER NOT NULL DEFAULT 0,
        total_study_days INTEGER NOT NULL DEFAULT 0,
        last_study_date TEXT NOT NULL DEFAULT '',
        total_study_minutes INTEGER NOT NULL DEFAULT 0,
        updated_at INTEGER NOT NULL
      )
    ''');
    // Initialize default user stats
    await db.insert('user_stats', {
      'id': 1,
      'updated_at': DateTime.now().millisecondsSinceEpoch
    });

    // 6. DailyRecords table
    await db.execute('''
      CREATE TABLE daily_records (
        date TEXT PRIMARY KEY NOT NULL,
        new_words_count INTEGER NOT NULL DEFAULT 0,
        review_words_count INTEGER NOT NULL DEFAULT 0,
        correct_count INTEGER NOT NULL DEFAULT 0,
        wrong_count INTEGER NOT NULL DEFAULT 0,
        study_minutes INTEGER NOT NULL DEFAULT 0,
        created_at INTEGER NOT NULL
      )
    ''');
    await db.execute('CREATE INDEX idx_daily_records_date ON daily_records(date)');
    
    // Seed data immediately after creation
    await _seedData(db);
  }

  Future<void> _onOpen(Database db) async {
    // Check if data exists, if not seed (useful if DB created but seeding failed or logic changed)
    final count = Sqflite.firstIntValue(await db.rawQuery('SELECT COUNT(*) FROM words'));
    if (count == 0) {
      await _seedData(db);
    }
  }

  Future<void> _seedData(Database db) async {
    print('Starting data seeding...');
    final files = [
      '外研版初中英语七年级上册.txt',
      '外研版初中英语七年级下册.txt',
      '外研版初中英语八年级上册.txt',
      '外研版初中英语八年级下册.txt',
      '外研版初中英语九年级上册.txt',
      '外研版初中英语九年级下册.txt',
    ];

    try {
      final batch = db.batch();

      for (final fileName in files) {
        final content = await rootBundle.loadString('assets/data/$fileName');
        final lines = content.split('\n');

        int grade = 7;
        if (fileName.contains('八年级')) grade = 8;
        if (fileName.contains('九年级')) grade = 9;

        int semester = 1;
        if (fileName.contains('下册')) semester = 2;

        String currentUnit = 'Module 1';
        int unitIndex = 1;
        int wordIndex = 0;

        for (var line in lines) {
          line = line.trim();
          if (line.isEmpty) continue;

          if (line.startsWith('#')) {
            // New Module
            currentUnit = line.substring(1).trim(); // Remove #
            if (currentUnit.isEmpty) currentUnit = 'Module 1';
            
            // Extract unit number if possible for sorting, or just increment
            unitIndex++; 
            wordIndex = 0; // Reset word index for new unit
            continue;
          }

          // It's a word
          wordIndex++;
          final wordId = 'word_${grade}_${semester}_${unitIndex}_$wordIndex';
          
          final word = Word(
            id: wordId,
            text: line,
            meaning: '[释义]', // Placeholder
            phonetic: '/phonetic/', // Placeholder
            grade: grade,
            semester: semester,
            unit: currentUnit,
            difficulty: 1,
            category: 'general',
          );

          batch.insert('words', word.toJson(), conflictAlgorithm: ConflictAlgorithm.replace);
        }
      }

      await batch.commit(noResult: true);
      print('Data seeding completed.');
    } catch (e) {
      print('Error seeding data: $e');
    }
  }

  // Helper method to reset DB (for debugging)
  Future<void> resetDB() async {
     final dbPath = await getDatabasesPath();
     final path = join(dbPath, 'wordcard_coach.db');
     await deleteDatabase(path);
     _database = null;
  }
}

import 'dart:async';
import 'package:flutter/services.dart' show rootBundle;
import 'dart:convert';
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
      version: 3,
      onCreate: _createDB,
      onUpgrade: _onUpgrade,
      onOpen: _onOpen,
    );
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
      // For development simplicity, just drop all and recreate
      await db.execute('DROP TABLE IF EXISTS words');
      await db.execute('DROP TABLE IF EXISTS sentences');
      await db.execute('DROP TABLE IF EXISTS word_sentence_map');
      await db.execute('DROP TABLE IF EXISTS word_progress');
      await db.execute('DROP TABLE IF EXISTS user_stats');
      await db.execute('DROP TABLE IF EXISTS daily_records');
      await _createDB(db, newVersion);
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
        category TEXT NOT NULL,
        syllables TEXT
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
    
    // Support both TXT (legacy) and JSON (new rich data)
    // We will prioritize JSON files if they exist.
    
    // Example: user generates "grade7_vol1_module1.json"
    // For now, let's look for a specific manifest or just scan known filenames.
    // To keep it simple for the user, let's assume they might drop "grade7_vol1.json" which contains multiple modules,
    // OR "grade7_vol1_module1.json". 
    // Let's iterate through the standard list and check for .json extension first.
    
    final books = [
      {'name': '外研版初中英语七年级上册', 'grade': 7, 'semester': 1},
      {'name': '外研版初中英语七年级下册', 'grade': 7, 'semester': 2},
      {'name': '外研版初中英语八年级上册', 'grade': 8, 'semester': 1},
      {'name': '外研版初中英语八年级下册', 'grade': 8, 'semester': 2},
      {'name': '外研版初中英语九年级上册', 'grade': 9, 'semester': 1},
      {'name': '外研版初中英语九年级下册', 'grade': 9, 'semester': 2},
    ];

    try {
      final batch = db.batch();

      for (final book in books) {
        final baseName = book['name'] as String;
        final grade = book['grade'] as int;
        final semester = book['semester'] as int;

        // Try JSON first
        try {
          // We assume the user might name it "外研版初中英语七年级上册.json"
          final jsonContent = await rootBundle.loadString('assets/data/$baseName.json');
          print("Found JSON for $baseName, importing rich data...");
          await _seedFromJson(batch, jsonContent, grade, semester);
          continue; // Successfully imported JSON, skip TXT
        } catch (e) {
          // JSON not found, fall back to TXT
          // print("JSON not found for $baseName, trying TXT...");
        }

        // Fallback to TXT
        try {
          final txtContent = await rootBundle.loadString('assets/data/$baseName.txt');
          print("Found TXT for $baseName, importing basic data...");
          await _seedFromTxt(batch, txtContent, grade, semester);
        } catch (e) {
          // print("TXT not found for $baseName: $e");
        }
      }

      await batch.commit(noResult: true);
      print('Data seeding completed.');
    } catch (e) {
      print('Error seeding data: $e');
    }
  }

  Future<void> _seedFromJson(Batch batch, String jsonString, int grade, int semester) async {
    // Expected JSON structure:
    // {
    //   "grade": 7,     <-- Optional coverage override
    //   "semester": 1,  <-- Optional coverage override
    //   "unit": "Module 1", <-- If file is per-module (or handled inside array)
    //   "data": [ ... ]
    // }
    // OR if it's a list of modules/words directly.
    // Based on user agreement:
    // {
    //   "grade": 7,
    //   "semester": 1,
    //   "unit": "Module 1",
    //   "data": [
    //     { "text": "hello", "phonetic": "...", "meaning": "...", "app_sentences": [...] }
    //   ]
    // }
    
    // We should be robust. Let's decode dynamically.
    final dynamic decoded = jsonDecode(jsonString);
    
    List<dynamic> items = [];
    String defaultUnit = "Module 1";
    
    if (decoded is List) {
      // List of modules or words? 
      // If user merges multiple module JSONs into one array:
      // [ { "unit": "M1", "data": [...] }, { "unit": "M2", "data": [...] } ]
      // We will handle that.
      items = decoded;
    } else if (decoded is Map<String, dynamic>) {
       // Single object
       if (decoded.containsKey('data')) {
          // It's the structure we agreed on
          if (decoded.containsKey('unit')) defaultUnit = decoded['unit'];
          items = decoded['data'];
       } else if (decoded.containsKey('words')) {
           // Maybe user uses 'words' key
           items = decoded['words'];
       }
    }

    // Checking if items are Words or Modules
    // If the agreed structure is { unit:..., data: [words] }, then items is [words].
    // But if input is [ {unit:..., data:[words]}, ... ], then items is [modules].
    
    // Let's handle the simple case agreed: Single Module File or Single List of Word Objects
    // Code below handles "List of Words" where context is passed in arguments or root object.
    
    int wordIndex = 0;
    
    for (var item in items) {
      if (item is Map<String, dynamic>) {
         // Determine if this is a WORD or a MODULE wrapper
         if (item.containsKey('data') || item.containsKey('words')) {
           // It's a module wrapper (recursive)
           // e.g. { "unit": "Module 2", "data": [words...] }
           final moduleUnit = item['unit'] ?? defaultUnit;
           final moduleData = item['data'] ?? item['words'] ?? [];
           await _seedWordList(batch, moduleData, grade, semester, moduleUnit);
         } else {
           // It's a word object directly
           // We use the defaultUnit logic (which might need to be passed down if it changes)
           // If we are processing a flat list of words, they all belong to 'defaultUnit' which might be wrong if the file covers whole book.
           // However, for the agreed "Per Module" JSON, this is correct.
           // We will delegate to a helper to write the single word.
           wordIndex++;
           _insertWord(batch, item, grade, semester, defaultUnit, wordIndex);
         }
      }
    }
  }
  
  // Helper for recursive module list processing
  Future<void> _seedWordList(Batch batch, List<dynamic> words, int grade, int semester, String unit) async {
    int wordIndex = 0;
    for (var w in words) {
      if (w is Map<String, dynamic>) {
        wordIndex++;
        _insertWord(batch, w, grade, semester, unit, wordIndex);
      }
    }
  }

  void _insertWord(Batch batch, Map<String, dynamic> data, int grade, int semester, String unit, int index) {
     final text = data['text'] as String? ?? '';
     if (text.isEmpty) return;
     
     final id = 'word_${grade}_${semester}_${unit.hashCode}_$index';
     
     List<String> syllables = [];
     if (data['syllables'] != null && data['syllables'] is List) {
       syllables = List<String>.from(data['syllables']);
     }

     final word = Word(
       id: id,
       text: text,
       meaning: data['meaning'] ?? '[释义]',
       phonetic: data['phonetic'] ?? '',
       grade: grade,
       semester: semester,
       unit: unit,
       difficulty: 1,
       category: 'general',
       syllables: syllables,
     );
     
     batch.insert('words', word.toJson(), conflictAlgorithm: ConflictAlgorithm.replace);
     
     // Handle Sentences
     if (data.containsKey('app_sentences')) {
       final sentences = data['app_sentences'] as List;
       int sIndex = 0;
       for (var s in sentences) {
         if (s is Map<String, dynamic>) {
           sIndex++;
           final en = s['en'] as String? ?? '';
           final cn = s['cn'] as String? ?? '';
           if (en.isNotEmpty) {
             final sId = 'sentence_${id}_$sIndex';
             
             // Insert Sentence
             batch.insert('sentences', {
               'id': sId,
               'text': en,
               'translation': cn,
               'category': 'example',
               'difficulty': 1
             }, conflictAlgorithm: ConflictAlgorithm.replace);
             
             // Insert Map
             batch.insert('word_sentence_map', {
               'word_id': id,
               'sentence_id': sId,
               'is_primary': sIndex == 1 ? 1 : 0, // First one is primary
               'word_position': -1 // Not calculating position for now
             }, conflictAlgorithm: ConflictAlgorithm.replace);
           }
         }
       }
     }
  }

  Future<void> _seedFromTxt(Batch batch, String content, int grade, int semester) async {
        final lines = content.split('\n');
        String currentUnit = 'Module 1';
        int unitIndex = 1;
        int wordIndex = 0;

        for (var line in lines) {
          line = line.trim();
          if (line.isEmpty) continue;

          if (line.startsWith('#')) {
            currentUnit = line.substring(1).trim(); 
            if (currentUnit.isEmpty) currentUnit = 'Module 1';
            unitIndex++; 
            wordIndex = 0; 
            continue;
          }

          wordIndex++;
          final wordId = 'word_${grade}_${semester}_${unitIndex}_$wordIndex';
          
          final word = Word(
            id: wordId,
            text: line,
            meaning: '[释义]', 
            phonetic: '/phonetic/', 
            grade: grade,
            semester: semester,
            unit: currentUnit,
            difficulty: 1,
            category: 'general',
          );

          batch.insert('words', word.toJson(), conflictAlgorithm: ConflictAlgorithm.replace);
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

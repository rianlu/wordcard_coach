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
      version: 4,
      onCreate: _createDB,
      onUpgrade: _onUpgrade,
      onOpen: _onOpen,
    );
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 3) {
      // Legacy: Drop all for very old versions (dev only)
      await db.execute('DROP TABLE IF EXISTS words');
      await db.execute('DROP TABLE IF EXISTS sentences');
      await db.execute('DROP TABLE IF EXISTS word_sentence_map');
      await db.execute('DROP TABLE IF EXISTS word_progress');
      await db.execute('DROP TABLE IF EXISTS user_stats');
      await db.execute('DROP TABLE IF EXISTS daily_records');
      await _createDB(db, newVersion);
      return; 
    }

    if (oldVersion < 4) {
      // Safe Migration v3 -> v4 (add sync columns)
      print("Migrating DB to version 4 (Cloud Sync Prep)...");
      
      // 1. word_progress
      await _safeAddColumn(db, 'word_progress', 'account_id', 'TEXT');
      await _safeAddColumn(db, 'word_progress', 'device_id', 'TEXT');
      await _safeAddColumn(db, 'word_progress', 'last_updated_at', 'INTEGER DEFAULT 0');
      await _safeAddColumn(db, 'word_progress', 'is_deleted', 'INTEGER DEFAULT 0');

      // 2. user_stats
      await _safeAddColumn(db, 'user_stats', 'account_id', 'TEXT');
      await _safeAddColumn(db, 'user_stats', 'device_id', 'TEXT');
      await _safeAddColumn(db, 'user_stats', 'last_updated_at', 'INTEGER DEFAULT 0');

      // 3. daily_records
      await _safeAddColumn(db, 'daily_records', 'account_id', 'TEXT');
      await _safeAddColumn(db, 'daily_records', 'device_id', 'TEXT');
      await _safeAddColumn(db, 'daily_records', 'last_updated_at', 'INTEGER DEFAULT 0');
      await _safeAddColumn(db, 'daily_records', 'is_deleted', 'INTEGER DEFAULT 0');

      // 4. sync_state table
      await db.execute('''
        CREATE TABLE IF NOT EXISTS sync_state (
          table_name TEXT PRIMARY KEY NOT NULL,
          last_synced_at INTEGER DEFAULT 0
        )
      ''');
    }
  }

  // Helper for safe column addition
  Future<void> _safeAddColumn(Database db, String table, String column, String type) async {
    try {
      await db.execute('ALTER TABLE $table ADD COLUMN $column $type');
    } catch (e) {
      // Ignore if column exists
      print("Column $column already exists in $table");
    }
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
        book_id TEXT NOT NULL DEFAULT '',
        syllables TEXT
      )
    ''');
    await db.execute('CREATE INDEX idx_words_book ON words(book_id)');
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
        account_id TEXT,
        device_id TEXT,
        last_updated_at INTEGER DEFAULT 0,
        is_deleted INTEGER DEFAULT 0,
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
        current_book_id TEXT NOT NULL DEFAULT '',
        account_id TEXT,
        device_id TEXT,
        last_updated_at INTEGER DEFAULT 0,
        updated_at INTEGER NOT NULL
      )
    ''');
    // Initialize default user stats
    await db.insert('user_stats', {
      'id': 1,
      'updated_at': DateTime.now().millisecondsSinceEpoch,
      'current_book_id': ''
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
        account_id TEXT,
        device_id TEXT,
        last_updated_at INTEGER DEFAULT 0,
        is_deleted INTEGER DEFAULT 0,
        created_at INTEGER NOT NULL
      )
    ''');
    await db.execute('CREATE INDEX idx_daily_records_date ON daily_records(date)');

    // 7. Sync State Table
    await db.execute('''
      CREATE TABLE sync_state (
        table_name TEXT PRIMARY KEY NOT NULL,
        last_synced_at INTEGER DEFAULT 0
      )
    ''');
    
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
    print('Starting data seeding from MANIFEST...');
    
    List<dynamic> manifest = [];
    try {
      final  manifestContent = await rootBundle.loadString('assets/data/books_manifest.json');
      manifest = jsonDecode(manifestContent);
      print('Loaded manifest with ${manifest.length} books.');
    } catch(e) {
      print('Manifest load failed: $e. Falling back to legacy list.');
      // Fallback or empty - currently empty fallback
    }
    
    if (manifest.isEmpty) {
       print("Warning: Manifest empty or failed.");
       return; 
    }

    try {
      final batch = db.batch();

      for (final book in manifest) {
        final bookId = book['id'] as String;
        final filename = book['file'] as String;
        final grade = book['grade'] as int;
        final semester = book['semester'] as int;
        
        // Try JSON
        try {
          final jsonContent = await rootBundle.loadString('assets/data/$filename');
          print("Importing $filename for book $bookId...");
          await _seedFromJson(batch, jsonContent, grade, semester, bookId);
        } catch (e) {
          print("Error loading $filename: $e");
        }
      }

      await batch.commit(noResult: true);
      print('Data seeding completed.');
      
      // Auto-select the first book if available
      if (manifest.isNotEmpty) {
        final firstBook = manifest.first;
        final bookId = firstBook['id'] as String;
        final grade = firstBook['grade'] as int;
        final semester = firstBook['semester'] as int;
        
        await db.update('user_stats', {
          'current_book_id': bookId,
          'current_grade': grade,
          'current_semester': semester
        }, where: 'id = 1');
        print('Auto-selected default book: $bookId');
      }
      
    } catch (e) {
      print('Error seeding data: $e');
    }
  }

  Future<void> _seedFromJson(Batch batch, String jsonString, int grade, int semester, String bookId) async {
    // Expected JSON structure:
    // {
    //   "grade": 7,     <-- Optional coverage override
    //   "semester": 1,  <-- Optional coverage override
    //   "unit": "Module 1", <-- If file is per-module (or handled inside array)
    //   "data": [ ... ]
    // }
    
    // We should be robust. Let's decode dynamically.
    final dynamic decoded = jsonDecode(jsonString);
    
    List<dynamic> items = [];
    String defaultUnit = "Module 1";
    
    if (decoded is List) {
      // List of modules or words? 
      items = decoded;
    } else if (decoded is Map<String, dynamic>) {
       if (decoded.containsKey('data')) {
          if (decoded.containsKey('unit')) defaultUnit = decoded['unit'];
          items = decoded['data'];
       } else if (decoded.containsKey('words')) {
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
           final moduleUnit = item['unit'] ?? defaultUnit;
           final moduleData = item['data'] ?? item['words'] ?? [];
           await _seedWordList(batch, moduleData, grade, semester, moduleUnit, bookId);
         } else {
           // It's a word object directly
           wordIndex++;
           _insertWord(batch, item, grade, semester, defaultUnit, wordIndex, bookId);
         }
      }
    }
  }
  
  // Helper for recursive module list processing
  Future<void> _seedWordList(Batch batch, List<dynamic> words, int grade, int semester, String unit, String bookId) async {
    int wordIndex = 0;
    for (var w in words) {
      if (w is Map<String, dynamic>) {
        wordIndex++;
        _insertWord(batch, w, grade, semester, unit, wordIndex, bookId);
      }
    }
  }

  void _insertWord(Batch batch, Map<String, dynamic> data, int grade, int semester, String unit, int index, String bookId) {
     final text = data['text'] as String? ?? '';
     if (text.isEmpty) return;
     
     final id = 'word_${bookId}_${unit.hashCode}_$index';
     
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
       bookId: bookId,
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

  /// Safe Update: Updates words from JSON without deleting progress
  Future<void> updateLibraryFromAssets() async {
    final db = await database;
    print('Starting SAFE library update from MANIFEST...');
    
    List<dynamic> manifest = [];
    try {
      final manifestContent = await rootBundle.loadString('assets/data/books_manifest.json');
      manifest = jsonDecode(manifestContent);
      print('Loaded manifest with ${manifest.length} books.');
    } catch(e) {
      print('Manifest load failed: $e');
      return;
    }
    
    if (manifest.isEmpty) return;

    try {
      final batch = db.batch();

      for (final book in manifest) {
        final bookId = book['id'] as String;
        final filename = book['file'] as String;
        final grade = book['grade'] as int;
        final semester = book['semester'] as int;
        
        try {
          final jsonContent = await rootBundle.loadString('assets/data/$filename');
          print("Updating $filename for book $bookId...");
          await _safeSeedFromJson(batch, jsonContent, grade, semester, bookId);
        } catch (e) {
          print("Error loading $filename: $e");
        }
      }

      await batch.commit(noResult: true);
      print('Library update completed successfully.');
      
    } catch (e) {
      print('Error updating library: $e');
    }
  }

  Future<void> _safeSeedFromJson(Batch batch, String jsonString, int grade, int semester, String bookId) async {
    final dynamic decoded = jsonDecode(jsonString);
    List<dynamic> items = [];
    String defaultUnit = "Module 1";
    
    if (decoded is List) {
      items = decoded;
    } else if (decoded is Map<String, dynamic>) {
       if (decoded.containsKey('data')) {
          if (decoded.containsKey('unit')) defaultUnit = decoded['unit'];
          items = decoded['data'];
       } else if (decoded.containsKey('words')) {
           items = decoded['words'];
       }
    }
    
    int wordIndex = 0;
    for (var item in items) {
      if (item is Map<String, dynamic>) {
         if (item.containsKey('data') || item.containsKey('words')) {
           final moduleUnit = item['unit'] ?? defaultUnit;
           final moduleData = item['data'] ?? item['words'] ?? [];
           await _safeSeedWordList(batch, moduleData, grade, semester, moduleUnit, bookId);
         } else {
           wordIndex++;
           _upsertWord(batch, item, grade, semester, defaultUnit, wordIndex, bookId);
         }
      }
    }
  }

  Future<void> _safeSeedWordList(Batch batch, List<dynamic> words, int grade, int semester, String unit, String bookId) async {
    int wordIndex = 0;
    for (var w in words) {
      if (w is Map<String, dynamic>) {
        wordIndex++;
        _upsertWord(batch, w, grade, semester, unit, wordIndex, bookId);
      }
    }
  }

  void _upsertWord(Batch batch, Map<String, dynamic> data, int grade, int semester, String unit, int index, String bookId) {
     final text = data['text'] as String? ?? '';
     if (text.isEmpty) return;
     
     final id = 'word_${bookId}_${unit.hashCode}_$index';
     
     // IMPORTANT: Use INSERT OR UPDATE logic to preserve ID and Foreign Keys
     // SQLite 'INSERT OR REPLACE' deletes the old row, triggering Cascade Delete on foreign keys.
     // We must use explicit UPSERT syntax.
     
     final meaning = data['meaning'] ?? '[释义]';
     final phonetic = data['phonetic'] ?? '';
     // Syllables and others
     String syllablesJson = '[]';
     if (data['syllables'] != null && data['syllables'] is List) {
       syllablesJson = jsonEncode(data['syllables']); // Store as simple string if needed or just comma sep
       // Actually 'words' table defines syllables as TEXT, but logic above used List -> which might be error in _insertWord? 
       // Checked _insertWord: it initializes List but ignores it for DB insert unless Word.toJson() handles it.
       // Word.toJson stores it as JSON string usually. Let's assume Word model handles serialization.
     }
     
     // Construct the SQL with rawInsert for Upsert support
     // ON CONFLICT(id) DO UPDATE SET ...
     batch.rawInsert('''
       INSERT INTO words (id, text, meaning, phonetic, grade, semester, unit, difficulty, category, book_id, syllables)
       VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
       ON CONFLICT(id) DO UPDATE SET
         text = excluded.text,
         meaning = excluded.meaning,
         phonetic = excluded.phonetic,
         syllables = excluded.syllables,
         unit = excluded.unit
     ''', [
       id, text, meaning, phonetic, grade, semester, unit, 1, 'general', bookId, syllablesJson
     ]);

      // Sentences: These are less critical to preserve progress since they don't hold progress directly (usually).
      // But WordSentenceMap does. 
      // For sentences, we can just replace them if their IDs are deterministic.
      // IDs are 'sentence_${wordId}_$index'.
      
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
             
             // Upsert Sentence
             batch.rawInsert('''
               INSERT INTO sentences (id, text, translation, category, difficulty)
               VALUES (?, ?, ?, ?, ?)
               ON CONFLICT(id) DO UPDATE SET
                 text = excluded.text,
                 translation = excluded.translation
             ''', [sId, en, cn, 'example', 1]);
             
             // Ensure Map exists (safe to replace strictly speaking as it's just a link)
             batch.insert('word_sentence_map', {
               'word_id': id,
               'sentence_id': sId,
               'is_primary': sIndex == 1 ? 1 : 0, 
               'word_position': -1
             }, conflictAlgorithm: ConflictAlgorithm.ignore); // Ignore if exists
           }
         }
       }
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

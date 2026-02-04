import 'package:sqflite/sqflite.dart';
import '../database_helper.dart';
import '../models/word.dart';
import '../models/word_progress.dart';
import '../../services/global_stats_notifier.dart';

class WordDao {
  final DatabaseHelper _dbHelper = DatabaseHelper();

  Future<int> insertWord(Word word) async {
    final db = await _dbHelper.database;
    return await db.insert('words', word.toJson(),
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<List<Word>> getAllWords() async {
    final db = await _dbHelper.database;
    final List<Map<String, dynamic>> maps = await db.query('words');
    return List.generate(maps.length, (i) {
      return Word.fromJson(maps[i]);
    });
  }

  Future<List<Word>> getWordsByUnit(int grade, int semester, String unit) async {
    final db = await _dbHelper.database;
    final List<Map<String, dynamic>> maps = await db.query(
      'words',
      where: 'grade = ? AND semester = ? AND unit = ?',
      whereArgs: [grade, semester, unit],
    );
    return List.generate(maps.length, (i) {
      return Word.fromJson(maps[i]);
    });
  }

  // Fetch sentences for a list of words
  Future<List<Word>> _attachSentences(List<Word> words) async {
    final db = await _dbHelper.database;
    List<Word> results = [];
    
    for (var word in words) {
      // Query sentences linked to this word
      final List<Map<String, dynamic>> sentenceMaps = await db.rawQuery('''
        SELECT s.text, s.translation 
        FROM sentences s
        JOIN word_sentence_map m ON s.id = m.sentence_id
        WHERE m.word_id = ?
        ORDER BY m.is_primary DESC, m.sentence_id ASC
      ''', [word.id]);
      
      List<Map<String, String>> examples = sentenceMaps.map((m) => {
        'en': m['text'] as String,
        'cn': m['translation'] as String
      }).toList();
      
      // Reconstitute word with examples
      results.add(Word(
        id: word.id,
        text: word.text,
        meaning: word.meaning,
        phonetic: word.phonetic,
        grade: word.grade,
        semester: word.semester,
        unit: word.unit,
        difficulty: word.difficulty,
        category: word.category,
        examples: examples
      ));
    }
    return results;
  }

  Future<List<Word>> getNewWords(int limit, {int? grade, int? semester}) async {
    final db = await _dbHelper.database;
    String whereClause = 'id NOT IN (SELECT word_id FROM word_progress)';
    List<dynamic> args = [];

    if (grade != null) {
      whereClause += ' AND grade = ?';
      args.add(grade);
    }
    if (semester != null) {
      whereClause += ' AND semester = ?';
      args.add(semester);
    }

    // args for LIMIT
    args.add(limit);

    final List<Map<String, dynamic>> maps = await db.rawQuery('''
      SELECT * FROM words 
      WHERE $whereClause
      ORDER BY rowid ASC
      LIMIT ?
    ''', args);
    
    final words = List.generate(maps.length, (i) {
      return Word.fromJson(maps[i]);
    });
    
    return await _attachSentences(words);
  }

  Future<List<Word>> getWordsDueForReview(int limit, {String? bookId, int? grade, int? semester}) async {
    final db = await _dbHelper.database;
    
    // Calculate end of today (23:59:59) to include everything scheduled for today
    final now = DateTime.now();
    final endOfToday = DateTime(now.year, now.month, now.day, 23, 59, 59).millisecondsSinceEpoch;
    
    // We join words and word_progress
    // Filter words that ARE in word_progress AND next_review_date <= endOfToday
    
    String whereClause = 'p.next_review_date <= ?';
    List<dynamic> args = [endOfToday];

    // Filter by book if possible
    if (bookId != null && bookId.isNotEmpty) {
       whereClause += ' AND w.book_id = ?';
       args.add(bookId);
    } else {
      // Legacy fallback
      if (grade != null) {
        whereClause += ' AND w.grade = ?';
        args.add(grade);
      }
      if (semester != null) {
        whereClause += ' AND w.semester = ?';
        args.add(semester);
      }
    }

    final List<Map<String, dynamic>> maps = await db.rawQuery('''
      SELECT w.* 
      FROM words w
      INNER JOIN word_progress p ON w.id = p.word_id
      WHERE $whereClause
      ORDER BY p.next_review_date ASC
      LIMIT ?
    ''', [...args, limit]);
    
    final words = List.generate(maps.length, (i) {
      return Word.fromJson(maps[i]);
    });
    
    return await _attachSentences(words);
  }

  Future<void> batchMarkAsLearned(List<Word> words) async {
    final db = await _dbHelper.database;
    final batch = db.batch();
    final now = DateTime.now().millisecondsSinceEpoch;

    for (var word in words) {
      batch.insert('word_progress', {
        'id': 'progress_${word.id}',
        'word_id': word.id,
        'created_at': now,
        'updated_at': now,
        // Defaults:
        'easiness_factor': 2.5,
        'interval': 1,
        'repetition': 0,
        'next_review_date': now + 86400000,
        'last_review_date': now,
        'review_count': 1, // Count as 1 review (the learning session)
        'mastery_level': 1, // Level 1 = Learned
      }, conflictAlgorithm: ConflictAlgorithm.ignore);
    }

    await batch.commit(noResult: true);
    GlobalStatsNotifier.instance.notify();
  }

  Future<List<Word>> getRandomWords(int limit) async {
    final db = await _dbHelper.database;
    final List<Map<String, dynamic>> maps = await db.query(
      'words',
      orderBy: 'RANDOM()',
      limit: limit,
    );
     final words = List.generate(maps.length, (i) {
      return Word.fromJson(maps[i]);
    });
    // We don't necessarily need sentences for distractors
    return words;
  }

  Future<void> updateReviewStats(String wordId, int quality) async {
    final db = await _dbHelper.database;
    final now = DateTime.now().millisecondsSinceEpoch;

    // 1. Get current progress
    final List<Map<String, dynamic>> maps = await db.query(
      'word_progress',
      where: 'word_id = ?',
      whereArgs: [wordId],
    );

    if (maps.isEmpty) return;

    final current = WordProgress.fromJson(maps.first);

    // 2. SM-2 Algorithm Calculation
    double oldEf = current.easinessFactor;
    int oldInterval = current.interval;
    int repetition = current.repetition;

    double newEf = oldEf;
    int newInterval = oldInterval;

    if (quality >= 3) {
      newEf = oldEf + (0.1 - (5 - quality) * (0.08 + (5 - quality) * 0.02));
      if (newEf < 1.3) newEf = 1.3;

      repetition += 1;

      if (repetition == 1) {
        newInterval = 1;
      } else if (repetition == 2) {
        newInterval = 6;
      } else {
        newInterval = (oldInterval * newEf).round();
      }
    } else {
      repetition = 0;
      newInterval = 1;
    }

    // 3. Determine Mastery Level
    int newMastery = (newInterval > 21) ? 2 : 1;

    // 4. Update DB
    await db.update(
      'word_progress',
      {
        'easiness_factor': newEf,
        'interval': newInterval,
        'repetition': repetition,
        'next_review_date': now + (newInterval * 24 * 60 * 60 * 1000),
        'last_review_date': now,
        'review_count': current.reviewCount + 1,
        'correct_count': current.correctCount + (quality >= 3 ? 1 : 0),
        'wrong_count': current.wrongCount + (quality < 3 ? 1 : 0),
        'mastery_level': newMastery,
        'updated_at': now,
      },
      where: 'word_id = ?',
      whereArgs: [wordId],
    );
    GlobalStatsNotifier.instance.notify();
  }

  Future<Map<int, int>> getWordCounts({String? bookId, String? unit, String? searchQuery}) async {
    final db = await _dbHelper.database;
    String whereClause = '1=1';
    List<dynamic> args = [];

    if (bookId != null && bookId.isNotEmpty) {
      whereClause += ' AND w.book_id = ?';
      args.add(bookId);
    }
    if (unit != null && unit.isNotEmpty) {
      whereClause += ' AND w.unit = ?';
      args.add(unit);
    }
    if (searchQuery != null && searchQuery.isNotEmpty) {
      whereClause += ' AND (w.text LIKE ? OR w.meaning LIKE ?)';
      args.add('%$searchQuery%');
      args.add('%$searchQuery%');
    }

    final List<Map<String, dynamic>> result = await db.rawQuery('''
      SELECT IFNULL(s.mastery_level, 0) as status, COUNT(*) as count
      FROM words w
      LEFT JOIN word_progress s ON w.id = s.word_id
      WHERE $whereClause
      GROUP BY IFNULL(s.mastery_level, 0)
    ''', args);
    
    final Map<int, int> counts = {0: 0, 1: 0, 2: 0};
    for (var row in result) {
      int status = row['status'] as int;
      int count = row['count'] as int;
      counts[status] = count;
    }
    return counts;
  }

  /// Fetch words for Dictionary with filters and pagination
  Future<List<Map<String, dynamic>>> getDictionaryWords({
    int limit = 50,
    int offset = 0,
    int? masteryFilter, // 0=New, 1=Learning, 2=Mastered. null=All
    String? searchQuery,
    String? bookId,
    String? unit,
  }) async {
    final db = await _dbHelper.database;
    
    // Base query: Join words with left join on progress
    String sql = '''
      SELECT w.*, 
             p.mastery_level,
             p.next_review_date,
             p.interval,
             p.easiness_factor,
             CASE WHEN p.id IS NULL THEN 0 ELSE 1 END as is_learned
      FROM words w
      LEFT JOIN word_progress p ON w.id = p.word_id
    ''';

    List<String> whereConditions = [];
    List<dynamic> args = [];

    // Filter by mastery
    if (masteryFilter != null) {
      if (masteryFilter == 0) {
        // "New" means no progress record OR mastery_level 0
        whereConditions.add('(p.id IS NULL OR p.mastery_level = 0)');
      } else {
        whereConditions.add('p.mastery_level = ?');
        args.add(masteryFilter);
      }
    }

    // Search
    if (searchQuery != null && searchQuery.isNotEmpty) {
      whereConditions.add('w.text LIKE ?');
      args.add('$searchQuery%'); // Prefix search
    }
    
    if (bookId != null && bookId.isNotEmpty) {
        whereConditions.add('w.book_id = ?');
        args.add(bookId);
    }

    if (unit != null && unit.isNotEmpty) {
        whereConditions.add('w.unit = ?');
        args.add(unit);
    }

    if (whereConditions.isNotEmpty) {
      sql += ' WHERE ${whereConditions.join(' AND ')}';
    }

    // Order by logical sequence: Grade -> Semester -> Unit -> ID (assuming insertion order)
    sql += ' ORDER BY w.grade ASC, w.semester ASC, w.unit ASC, w.id ASC LIMIT ? OFFSET ?';
    args.add(limit);
    args.add(offset);

    return await db.rawQuery(sql, args);
  }

  Future<List<String>> getUnitsForBook(String bookId) async {
    final db = await _dbHelper.database;
    // Sort by insertion order (rowid) to keep original book order (Module 1, 2... 10)
    // instead of alphabetical (1, 10, 2)
    final List<Map<String, dynamic>> maps = await db.rawQuery(
      'SELECT unit FROM words WHERE book_id = ? GROUP BY unit ORDER BY MIN(rowid) ASC', 
      [bookId]
    );
    return maps.map((e) => e['unit'] as String).toList();
  }

  /// Get full word details including sentences/examples
  Future<Word?> getWordDetails(String wordId) async {
    final db = await _dbHelper.database;
    
    // 1. Get Word Basic Info
    final List<Map<String, dynamic>> wordMaps = await db.query(
      'words',
      where: 'id = ?',
      whereArgs: [wordId],
    );

    if (wordMaps.isEmpty) return null;
    
    // 2. Get Examples (Sentences)
    final List<Map<String, dynamic>> sentenceMaps = await db.rawQuery('''
      SELECT s.text as en, s.translation as cn
      FROM sentences s
      JOIN word_sentence_map m ON s.id = m.sentence_id
      WHERE m.word_id = ?
      ORDER BY m.is_primary DESC, m.word_position ASC
    ''', [wordId]);
    
    final Map<String, dynamic> wordData = Map<String, dynamic>.from(wordMaps.first);
    
    final List<Map<String, String>> examplesForJson = sentenceMaps.map((s) => {
      'text': s['en'] as String,
      'translation': s['cn'] as String
    }).toList();
    
    wordData['examples'] = examplesForJson;
    
    return Word.fromJson(wordData);
  }
}

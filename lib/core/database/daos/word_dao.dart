import 'package:sqflite/sqflite.dart';
import '../database_helper.dart';
import '../models/word.dart';

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
      ORDER BY RANDOM()
      LIMIT ?
    ''', args);
    
    final words = List.generate(maps.length, (i) {
      return Word.fromJson(maps[i]);
    });
    
    return await _attachSentences(words);
  }
}

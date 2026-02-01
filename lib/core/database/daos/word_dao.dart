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

  // Get words that don't have progress yet (new words), randomly
  Future<List<Word>> getNewWords(int limit) async {
    final db = await _dbHelper.database;
    // Simple implementation: words not in word_progress
    final List<Map<String, dynamic>> maps = await db.rawQuery('''
      SELECT * FROM words 
      WHERE id NOT IN (SELECT word_id FROM word_progress)
      ORDER BY RANDOM()
      LIMIT ?
    ''', [limit]);
    
    return List.generate(maps.length, (i) {
      return Word.fromJson(maps[i]);
    });
  }
}

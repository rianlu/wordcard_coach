import 'package:sqflite/sqflite.dart';
import '../database_helper.dart';
import '../models/user_stats.dart';

class UserStatsDao {
  final DatabaseHelper _dbHelper = DatabaseHelper();

  Future<UserStats> getUserStats() async {
    final db = await _dbHelper.database;
    final List<Map<String, dynamic>> maps = await db.query(
      'user_stats',
      where: 'id = ?',
      whereArgs: [1],
    );

    if (maps.isNotEmpty) {
      return UserStats.fromJson(maps.first);
    } else {
      // Should have been initialized by DatabaseHelper, but just in case
      final defaultStats = UserStats(updatedAt: DateTime.now().millisecondsSinceEpoch);
      await db.insert('user_stats', defaultStats.toJson());
      return defaultStats;
    }
  }

  Future<void> updateUserStats(UserStats stats) async {
    final db = await _dbHelper.database;
    await db.update(
      'user_stats',
      stats.toJson(),
      where: 'id = ?',
      whereArgs: [1],
    );
  }
}

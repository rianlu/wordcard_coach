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
      // 理论上已初始化，这里兜底
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

  Future<void> updateGrade(int grade, int semester) async {
    // 可能已废弃？或同时更新 教材编号
    // 暂仅更新年级/学期，后续迁移到统一入口
    final db = await _dbHelper.database;
    await db.update(
      'user_stats',
      {'current_grade': grade, 'current_semester': semester},
      where: 'id = ?',
      whereArgs: [1],
    );
  }

  Future<void> updateCurrentBook(String bookId, int grade, int semester) async {
    final db = await _dbHelper.database;
    await db.update(
      'user_stats',
      {
        'current_book_id': bookId,
        'current_grade': grade, 
        'current_semester': semester
      },
      where: 'id = ?',
      whereArgs: [1],
    );
  }
}

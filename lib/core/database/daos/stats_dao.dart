import 'package:sqflite/sqflite.dart';
import '../database_helper.dart';
import '../../services/global_stats_notifier.dart';

class DailyActivity {
  final String date;
  final int count;
  final int newCount;
  final int reviewCount;

  DailyActivity(this.date, this.count, {this.newCount = 0, this.reviewCount = 0});
}

class MasteryDistribution {
  final int newWords;
  final int learning;
  final int mastered;

  MasteryDistribution(this.newWords, this.learning, this.mastered);
}

class BookProgress {
  final int total;
  final int learned;
  
  double get percentage => total == 0 ? 0 : learned / total;

  BookProgress(this.total, this.learned);
}

class VocabGrowthPoint {
  final String date;
  final int totalWords; // 累计值
  
  VocabGrowthPoint(this.date, this.totalWords);
}

class RadarStats {
  final double vocabulary;
  final double spelling;
  final double memory;
  final double reaction;
  final double pronunciation;

  RadarStats({
    required this.vocabulary,
    required this.spelling,
    required this.memory,
    required this.reaction,
    required this.pronunciation,
  });
}

class PerformanceHighlight {
  final String title;
  final String subtitle;
  final String badgeText;
  final int colorValue; // 存为 便于传递，界面 再还原颜色
  final int iconCode; // 存储图标代码点

  PerformanceHighlight({
    required this.title,
    required this.subtitle,
    required this.badgeText,
    required this.colorValue,
    required this.iconCode,
  });
}

class AccuracyStats {
  final int correct;
  final int wrong;
  
  double get rate => (correct + wrong) == 0 ? 0 : correct / (correct + wrong);

  AccuracyStats(this.correct, this.wrong);
}

class StatsDao {
  final DatabaseHelper _dbHelper = DatabaseHelper();

  // 获取最近 7 天学习数量（新学+复习）
  Future<List<DailyActivity>> getWeeklyActivity() async {
    final db = await _dbHelper.database;
    final now = DateTime.now();
    List<DailyActivity> activity = [];

    // 预取最近 10 天记录以减少查询
    // 日期字符串映射到数量统计
    Map<String, Map<String, int>> activityMap = {};
    
    final List<Map<String, dynamic>> rows = await db.query(
      'daily_records',
      columns: ['date', 'new_words_count', 'review_words_count'],
      orderBy: 'date DESC', 
      limit: 10
    );
    
    for (var row in rows) {
      final date = row['date'] as String;
      final newC = (row['new_words_count'] as int);
      final revC = (row['review_words_count'] as int);
      activityMap[date] = {'new': newC, 'review': revC};
    }

    // 构建最近 7 天列表（按时间顺序）
    // 逻辑处理
    // 逻辑处理
    // 逻辑处理
    // 逻辑处理
    // 逻辑处理
    // 逻辑处理
    // 逻辑处理
    // 逻辑处理
    
    for (int i = 6; i >= 0; i--) {
      final date = now.subtract(Duration(days: i));
      final dateStr = "${date.year}-${date.month.toString().padLeft(2,'0')}-${date.day.toString().padLeft(2,'0')}";
      
      final int newC = activityMap[dateStr]?['new'] ?? 0;
      final int revC = activityMap[dateStr]?['review'] ?? 0;
      
      // 兼容旧格式键
      if (newC == 0 && revC == 0) {
         final legacyDateStr = "${date.year}-${date.month}-${date.day}";
         final int lNewC = activityMap[legacyDateStr]?['new'] ?? 0;
         final int lRevC = activityMap[legacyDateStr]?['review'] ?? 0;
         activity.add(DailyActivity(dateStr, lNewC + lRevC, newCount: lNewC, reviewCount: lRevC));
      } else {
         activity.add(DailyActivity(dateStr, newC + revC, newCount: newC, reviewCount: revC));
      }
    }
    
    return activity;
  }


  Future<MasteryDistribution> getMasteryDistribution(String bookId) async {
    final db = await _dbHelper.database;
    
    // 逻辑处理
    // 逻辑处理
    // 逻辑处理
    final int totalWords = Sqflite.firstIntValue(await db.rawQuery(
      'SELECT COUNT(*) FROM words WHERE book_id = ?',
      [bookId]
    )) ?? 0;
    
    // 逻辑处理
    // 逻辑处理
    final List<Map<String, dynamic>> progressMaps = await db.rawQuery('''
      SELECT wp.interval 
      FROM word_progress wp
      JOIN words w ON wp.word_id = w.id
      WHERE w.book_id = ?
    ''', [bookId]);
    
    int mastered = 0;
    int reviewing = 0;
    
    for (var map in progressMaps) {
      int interval = map['interval'] as int? ?? 0;
      
      if (interval >= 21) {
        mastered++;
      } else if (interval > 0) {
        reviewing++;
      } 
      // 逻辑处理
    }
    
    // 逻辑处理
    // 逻辑处理
    // 逻辑处理
    // 逻辑处理
    int newWords = totalWords - mastered - reviewing;
    if (newWords < 0) newWords = 0;

    return MasteryDistribution(newWords, reviewing, mastered);
  }

  Future<BookProgress> getBookProgress(String bookId) async {
    final db = await _dbHelper.database;
    
    // 该教材总单词数
    final int total = Sqflite.firstIntValue(await db.rawQuery(
      'SELECT COUNT(*) FROM words WHERE book_id = ?',
      [bookId]
    )) ?? 0;
    
    // 该教材已学习单词数
    // 关联单词进度与单词表过滤教材
    final int learned = Sqflite.firstIntValue(await db.rawQuery('''
      SELECT COUNT(*) FROM word_progress wp
      JOIN words w ON wp.word_id = w.id
      WHERE w.book_id = ?
    ''', [bookId])) ?? 0;
    
    return BookProgress(total, learned);
  }

  Future<AccuracyStats> getOverallAccuracy() async {
    final db = await _dbHelper.database;
    final result = await db.rawQuery(
      'SELECT SUM(correct_count) as c, SUM(wrong_count) as w FROM word_progress'
    );
    
    if (result.isEmpty) return AccuracyStats(0, 0);
    
    int c = (result.first['c'] as int?) ?? 0;
    int w = (result.first['w'] as int?) ?? 0;
    
    return AccuracyStats(c, w);
  }

  Future<List<VocabGrowthPoint>> getVocabularyGrowth() async {
     final db = await _dbHelper.database;
     List<VocabGrowthPoint> points = [];
     
     // 逻辑处理
     final List<Map<String, dynamic>> history = await db.query(
       'daily_records',
       columns: ['date', 'new_words_count'],
       orderBy: 'date ASC',
       limit: 30
     );
     
     // 逻辑处理
     if (history.isNotEmpty) {
       // 逻辑处理
       // 逻辑处理
       // 逻辑处理
       
       int currentTotal = 0;
       final statsMap = await db.query('user_stats', where: 'id = 1');
       if (statsMap.isNotEmpty) {
         currentTotal = statsMap.first['total_words_learned'] as int;
       }
       
       // 逻辑处理
       Map<String, int> dailyNewWords = {
         for (var item in history) (item['date'] as String): (item['new_words_count'] as int)
       };
       
       final now = DateTime.now();
       // 逻辑处理
       List<VocabGrowthPoint> reversePoints = [];
       
       int runningTotal = currentTotal;
       
       // 逻辑处理
       for (int i = 0; i < 7; i++) {
         final date = now.subtract(Duration(days: i));
         final dateStr = "${date.year}-${date.month.toString().padLeft(2,'0')}-${date.day.toString().padLeft(2,'0')}";
         
         // 逻辑处理
         reversePoints.add(VocabGrowthPoint(
           "${date.month}/${date.day}", 
           runningTotal
         ));
         
         // 逻辑处理
         // 逻辑处理
         int gainSteps = dailyNewWords[dateStr] ?? 0;
         
         // 逻辑处理
         if (gainSteps == 0) {
            String legacyDate = "${date.year}-${date.month}-${date.day}";
            gainSteps = dailyNewWords[legacyDate] ?? 0;
         }
         
         runningTotal -= gainSteps;
         if (runningTotal < 0) runningTotal = 0;
       }
       
       points = reversePoints.reversed.toList();
       
     } else {
       // 逻辑处理
       final statsMap = await db.query('user_stats', where: 'id = 1');
       int currentTotal = 0;
       if (statsMap.isNotEmpty) {
         currentTotal = statsMap.first['total_words_learned'] as int;
       }
       
       final now = DateTime.now();
       for (int i = 6; i >= 0; i--) {
         double factor = (1.0 - (i * 0.1)); 
         if (factor < 0) factor = 0;
         int val = (currentTotal * factor).round();
         String d = "${now.subtract(Duration(days: i)).day}/${now.subtract(Duration(days: i)).month}";
         points.add(VocabGrowthPoint(d, val));
       }
     }
     
     return points;
  }
  Future<RadarStats> getRadarStats() async {
     // 逻辑处理
     final growth = await getVocabularyGrowth();
     final vocabScore = (growth.isNotEmpty ? growth.last.totalWords : 0) / 1000.0; // 逻辑处理
     
     final accuracy = await getOverallAccuracy();
     
     return RadarStats(
       vocabulary: vocabScore.clamp(0.2, 1.0),
       spelling: accuracy.rate.clamp(0.4, 0.95), // 逻辑处理
       memory: 0.85, // 逻辑处理
       reaction: 0.7, // 逻辑处理
       pronunciation: 0.75, // 逻辑处理
     );
  }

  Future<List<DailyActivity>> getMonthlyActivity() async {
    final db = await _dbHelper.database;
    List<DailyActivity> activity = [];
    final now = DateTime.now();
    
    // 逻辑处理
    // 日期字符串映射到数量统计
    Map<String, Map<String, int>> activityMap = {};
    
    // 逻辑处理
    // 逻辑处理
    final List<Map<String, dynamic>> rows = await db.query(
      'daily_records',
      columns: ['date', 'new_words_count', 'review_words_count'],
      orderBy: 'date DESC', 
      limit: 35
    );
    
    for (var row in rows) {
      final date = row['date'] as String;
      final newC = (row['new_words_count'] as int);
      final revC = (row['review_words_count'] as int);
      activityMap[date] = {'new': newC, 'review': revC};
    }

    // 逻辑处理
    for (int i = 29; i >= 0; i--) {
      final date = now.subtract(Duration(days: i));
      // 逻辑处理
      // 逻辑处理
      // 逻辑处理
      final dateStr = "${date.year}-${date.month.toString().padLeft(2,'0')}-${date.day.toString().padLeft(2,'0')}";
      
      // 逻辑处理
      // 逻辑处理
      // 逻辑处理
      
      final int newC = activityMap[dateStr]?['new'] ?? 0;
      final int revC = activityMap[dateStr]?['review'] ?? 0;
      
      // 逻辑处理
      if (newC == 0 && revC == 0) {
         final legacyDateStr = "${date.year}-${date.month}-${date.day}";
         final int lNewC = activityMap[legacyDateStr]?['new'] ?? 0;
         final int lRevC = activityMap[legacyDateStr]?['review'] ?? 0;
         activity.add(DailyActivity(dateStr, lNewC + lRevC, newCount: lNewC, reviewCount: lRevC));
      } else {
         activity.add(DailyActivity(dateStr, newC + revC, newCount: newC, reviewCount: revC));
      }
    }
    return activity;
  }

  Future<List<PerformanceHighlight>> getPerformanceHighlights() async {
     final db = await _dbHelper.database;
     List<PerformanceHighlight> highlights = [];

     // 逻辑处理
     final List<Map<String, dynamic>> wrongest = await db.rawQuery('''
        SELECT w.text, wp.wrong_count 
        FROM word_progress wp 
        JOIN words w ON wp.word_id = w.id 
        ORDER BY wp.wrong_count DESC 
        LIMIT 1
     ''');
     
     if (wrongest.isNotEmpty && (wrongest.first['wrong_count'] as int) > 0) {
        final word = wrongest.first['text'] as String;
        final count = wrongest.first['wrong_count'] as int;
        highlights.add(PerformanceHighlight(
           title: "难点单词", 
           subtitle: word, 
           badgeText: "错 $count 次", 
           colorValue: 0xFFF59E0B, // 逻辑处理
           iconCode: 0xef76, // 逻辑处理
        ));
     } else {
        // 逻辑处理
         highlights.add(PerformanceHighlight(
           title: "暂无难点", 
           subtitle: "继续保持", 
           badgeText: "Perfect", 
           colorValue: 0xFFF59E0B, // 逻辑处理
           iconCode: 0xe87f, // 逻辑处理
        ));
     }

     // 逻辑处理
     // 逻辑处理
     final modeSums = await db.rawQuery('''
       SELECT 
         SUM(spell_mode_count) as spell, 
         SUM(speak_mode_count) as speak, 
         SUM(select_mode_count) as sel 
       FROM word_progress
     ''');
     
     if (modeSums.isNotEmpty) {
       final spell = (modeSums.first['spell'] as int?) ?? 0;
       final speak = (modeSums.first['speak'] as int?) ?? 0;
       final sel = (modeSums.first['sel'] as int?) ?? 0;
       
       String title = "全能选手";
       String sub = "综合即最强";
       if (spell >= speak && spell >= sel && spell > 0) {
          title = "拼写达人"; sub = "键盘敲击者";
       } else if (speak >= spell && speak >= sel && speak > 0) {
          title = "口语王者"; sub = "自信发音";
       } else if (sel > 0) {
          title = "敏锐直觉"; sub = "快速辨析";
       }
       
       highlights.add(PerformanceHighlight(
           title: title, 
           subtitle: sub, 
           badgeText: "S Rank", 
           colorValue: 0xFF3B82F6, // 逻辑处理
           iconCode: 0xe9f7, // 逻辑处理
       ));
     } else {
        highlights.add(PerformanceHighlight(
           title: "学习起步", 
           subtitle: "积累中...", 
           badgeText: "Level 1", 
           colorValue: 0xFF3B82F6, // 逻辑处理
           iconCode: 0xe88a, // 逻辑处理
       ));
     }
     
     return highlights;
  }

  /// 记录每日学习活动
  /// 更新或插入 日统计表
  Future<void> recordDailyActivity({
    required int newWords,
    required int reviewWords,
    required int correct,
    required int wrong,
    required int minutes,
    DateTime? date, // 可选日期用于历史数据
  }) async {
    final db = await _dbHelper.database;
    final targetDate = date ?? DateTime.now();
    // 日期格式：年-月-日
    final dateStr = "${targetDate.year}-${targetDate.month.toString().padLeft(2,'0')}-${targetDate.day.toString().padLeft(2,'0')}";
    
    // 检查记录是否存在
    final List<Map<String, dynamic>> existing = await db.query(
      'daily_records',
      where: 'date = ?',
      whereArgs: [dateStr],
    );

    if (existing.isNotEmpty) {
      // (累计值)
      final row = existing.first;
      await db.update(
        'daily_records',
        {
          'new_words_count': (row['new_words_count'] as int) + newWords,
          'review_words_count': (row['review_words_count'] as int) + reviewWords,
          'correct_count': (row['correct_count'] as int) + correct,
          'wrong_count': (row['wrong_count'] as int) + wrong,
          'study_minutes': (row['study_minutes'] as int) + minutes,
        },
        where: 'date = ?',
        whereArgs: [dateStr],
      );
    } else {
      // 插入新记录
      await db.insert('daily_records', {
        'date': dateStr,
        'new_words_count': newWords,
        'review_words_count': reviewWords,
        'correct_count': correct,
        'wrong_count': wrong,
        'study_minutes': minutes,
        'created_at': targetDate.millisecondsSinceEpoch,
      });
    }
    
    // 广播更新通知
    GlobalStatsNotifier.instance.notify();
  }
}

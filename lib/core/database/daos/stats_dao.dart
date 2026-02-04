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
  final int totalWords; // Cumulative
  
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
  final int colorValue; // Store int for easy passing, reconstruct Color in UI
  final int iconCode; // Store codePoint

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

  // Get learning count (new + review) for the last 7 days
  Future<List<DailyActivity>> getWeeklyActivity() async {
    final db = await _dbHelper.database;
    final now = DateTime.now();
    List<DailyActivity> activity = [];

    // Pre-fetch last 10 days of records to minimise queries
    // We map date string -> Map of counts
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

    // Build list for Last 7 Days (Today -> 6 days ago) in reverse order for chart usually?
    // Actually charts usually want Oldest -> Newest.
    // Let's return Today at index 0 or last? 
    // Usually lists are [Day 1, Day 2... Today].
    // But existing code logic in other methods was descending.
    // Let's provide Chronological Order: 6 days ago -> Today.
    // But wait, the Heatmap might expect specific order.
    // The previous mock loop was `for (int i = 6; i >= 0; i--)` which pushes [Day-6, Day-5 ... Today].
    // So distinct chronological order.
    
    for (int i = 6; i >= 0; i--) {
      final date = now.subtract(Duration(days: i));
      final dateStr = "${date.year}-${date.month.toString().padLeft(2,'0')}-${date.day.toString().padLeft(2,'0')}";
      
      final int newC = activityMap[dateStr]?['new'] ?? 0;
      final int revC = activityMap[dateStr]?['review'] ?? 0;
      
      // Fallback for legacy keys if any
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
    
    // 1. Total words in current book
    // If bookId is empty, we might want to scan all words or just return 0.
    // Assuming bookId provided correct context.
    final int totalWords = Sqflite.firstIntValue(await db.rawQuery(
      'SELECT COUNT(*) FROM words WHERE book_id = ?',
      [bookId]
    )) ?? 0;
    
    // 2. Analyze progress by Interval
    // We only care about words that have a progress record.
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
      // interval == 0 falls into "New" bucket conceptually along with unstudied words
    }
    
    // 3. Calc New (Total - Actively Studied)
    // "New" includes:
    //  a) Words strictly not in word_progress
    //  b) Words in word_progress but interval == 0 (Reset/Failed today)
    int newWords = totalWords - mastered - reviewing;
    if (newWords < 0) newWords = 0;

    return MasteryDistribution(newWords, reviewing, mastered);
  }

  Future<BookProgress> getBookProgress(String bookId) async {
    final db = await _dbHelper.database;
    
    // Total words in this book
    final int total = Sqflite.firstIntValue(await db.rawQuery(
      'SELECT COUNT(*) FROM words WHERE book_id = ?',
      [bookId]
    )) ?? 0;
    
    // Learned words in this book (exist in word_progress)
    // We join word_progress with words to filter by book_id
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
     
     // 1. Get accurate history from daily_records (Last 30 days)
     final List<Map<String, dynamic>> history = await db.query(
       'daily_records',
       columns: ['date', 'new_words_count'],
       orderBy: 'date ASC',
       limit: 30
     );
     
     // If we have real history, build the curve from it
     if (history.isNotEmpty) {
       // We need a baseline total from BEFORE the first record.
       // It's hard to know exactly without a "total_at_start_of_day" field.
       // Workaround: Get current total, then subtract backwards.
       
       int currentTotal = 0;
       final statsMap = await db.query('user_stats', where: 'id = 1');
       if (statsMap.isNotEmpty) {
         currentTotal = statsMap.first['total_words_learned'] as int;
       }
       
       // Map records by date for easy lookup
       Map<String, int> dailyNewWords = {
         for (var item in history) (item['date'] as String): (item['new_words_count'] as int)
       };
       
       final now = DateTime.now();
       // Generate points for last 7 days for the chart
       List<VocabGrowthPoint> reversePoints = [];
       
       int runningTotal = currentTotal;
       
       // Calculate backwards from Today (i=0) to 6 days ago
       for (int i = 0; i < 7; i++) {
         final date = now.subtract(Duration(days: i));
         final dateStr = "${date.year}-${date.month.toString().padLeft(2,'0')}-${date.day.toString().padLeft(2,'0')}";
         
         // Add point for current running total
         reversePoints.add(VocabGrowthPoint(
           "${date.month}/${date.day}", 
           runningTotal
         ));
         
         // Subtract today's gain to get yesterday's end total
         // Note: If date string format mismatches, we fallback to 0 subtraction
         int gainSteps = dailyNewWords[dateStr] ?? 0;
         
         // Try legacy format if missed
         if (gainSteps == 0) {
            String legacyDate = "${date.year}-${date.month}-${date.day}";
            gainSteps = dailyNewWords[legacyDate] ?? 0;
         }
         
         runningTotal -= gainSteps;
         if (runningTotal < 0) runningTotal = 0;
       }
       
       points = reversePoints.reversed.toList();
       
     } else {
       // Fallback: Simulation if strictly NO daily records exist yet
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
     // Mock logic for now, mixing with real data where possible
     final growth = await getVocabularyGrowth();
     final vocabScore = (growth.isNotEmpty ? growth.last.totalWords : 0) / 1000.0; // Normalize
     
     final accuracy = await getOverallAccuracy();
     
     return RadarStats(
       vocabulary: vocabScore.clamp(0.2, 1.0),
       spelling: accuracy.rate.clamp(0.4, 0.95), // Use real accuracy
       memory: 0.85, // Mock: No retention tracking yet
       reaction: 0.7, // Mock: No time tracking yet
       pronunciation: 0.75, // Mock: No pronunciation score yet
     );
  }

  Future<List<DailyActivity>> getMonthlyActivity() async {
    final db = await _dbHelper.database;
    List<DailyActivity> activity = [];
    final now = DateTime.now();
    
    // 1. Get stats for last 30 days
    // We map date string -> Map of counts
    Map<String, Map<String, int>> activityMap = {};
    
    // Query last 35 days to be safe
    // Since date is TEXT YYYY-MM-DD, we can check string range or just pull recent limits
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

    // 2. Build list for UI (last 30 days)
    for (int i = 29; i >= 0; i--) {
      final date = now.subtract(Duration(days: i));
      // Format must match DB: YYYY-MM-DD
      // Note: check how daily_record stores date. Assuming YYYY-MM-DD based on other files.
      // Need pads
      final dateStr = "${date.year}-${date.month.toString().padLeft(2,'0')}-${date.day.toString().padLeft(2,'0')}";
      
      // Fallback: Code elsewhere might use single digit?
      // Let's also check strict equality if simple query fails.
      // But for now, try formatted.
      
      final int newC = activityMap[dateStr]?['new'] ?? 0;
      final int revC = activityMap[dateStr]?['review'] ?? 0;
      
      // Fallback
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

     // 1. Find Weakness (Word with most wrongs)
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
           colorValue: 0xFFF59E0B, // Amber
           iconCode: 0xef76, // warning_amber or fitness_center
        ));
     } else {
        // Fallback Weakness
         highlights.add(PerformanceHighlight(
           title: "暂无难点", 
           subtitle: "继续保持", 
           badgeText: "Perfect", 
           colorValue: 0xFFF59E0B, // Amber
           iconCode: 0xe87f, // face
        ));
     }

     // 2. Find Strength (Most practiced mode or High Accuracy)
     // Let's check most practiced mode
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
           colorValue: 0xFF3B82F6, // Blue
           iconCode: 0xe9f7, // verified
       ));
     } else {
        highlights.add(PerformanceHighlight(
           title: "学习起步", 
           subtitle: "积累中...", 
           badgeText: "Level 1", 
           colorValue: 0xFF3B82F6, // Blue
           iconCode: 0xe88a, // home
       ));
     }
     
     return highlights;
  }

  /// Records daily learning activity.
  /// Upserts (Updates if exists, Inserts if new) into daily_records.
  Future<void> recordDailyActivity({
    required int newWords,
    required int reviewWords,
    required int correct,
    required int wrong,
    required int minutes,
  }) async {
    final db = await _dbHelper.database;
    final now = DateTime.now();
    // Format: YYYY-MM-DD
    final dateStr = "${now.year}-${now.month.toString().padLeft(2,'0')}-${now.day.toString().padLeft(2,'0')}";
    
    // Check if record exists
    final List<Map<String, dynamic>> existing = await db.query(
      'daily_records',
      where: 'date = ?',
      whereArgs: [dateStr],
    );

    if (existing.isNotEmpty) {
      // Update existing record (Cumulative)
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
      // Insert new record
      await db.insert('daily_records', {
        'date': dateStr,
        'new_words_count': newWords,
        'review_words_count': reviewWords,
        'correct_count': correct,
        'wrong_count': wrong,
        'study_minutes': minutes,
        'created_at': now.millisecondsSinceEpoch,
      });
    }
    
    // Broadcast update
    GlobalStatsNotifier.instance.notify();
  }
}

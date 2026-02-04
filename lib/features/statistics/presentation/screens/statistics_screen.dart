import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/database/daos/stats_dao.dart';
import '../../../../core/database/daos/user_stats_dao.dart';
import '../../../../core/database/models/user_stats.dart';
import '../../../../core/services/global_stats_notifier.dart';

import '../widgets/mastery_pie_chart.dart';
import '../widgets/weekly_bar_chart.dart';
import '../widgets/highlight_card.dart';
import '../widgets/study_heatmap.dart';

class StatisticsScreen extends StatefulWidget {
  const StatisticsScreen({super.key});

  @override
  State<StatisticsScreen> createState() => _StatisticsScreenState();
}

class _StatisticsScreenState extends State<StatisticsScreen> {
  final StatsDao _statsDao = StatsDao();
  // UserStats? _userStats; 
  // BookProgress? _bookProgress;
  // AccuracyStats? _accuracyStats;
  
  bool _isLoading = true;
  MasteryDistribution? _masteryDistribution;
  List<VocabGrowthPoint> _vocabGrowth = [];
  List<DailyActivity> _monthlyActivity = [];
  List<PerformanceHighlight> _highlights = [];
  double _retentionRate = 0.85; // Default fallback

  @override
  void initState() {
    super.initState();
    _loadData();
    GlobalStatsNotifier.instance.addListener(_loadData);
  }

  @override
  void dispose() {
    GlobalStatsNotifier.instance.removeListener(_loadData);
    super.dispose();
  }

  Future<void> _loadData() async {
    try {
      // Parallel fetch for efficiency
      // bookId should be dynamic, but for now using current context or fallback
       // Fetch UserStats to get bookID
       final userStats = await UserStatsDao().getUserStats();
       String bookId = userStats.currentBookId.isNotEmpty ? userStats.currentBookId : 'waiyan_3_1';
      
      final mastery = await _statsDao.getMasteryDistribution(bookId);
      final growth = await _statsDao.getVocabularyGrowth();
      final activity = await _statsDao.getMonthlyActivity();
      final highlights = await _statsDao.getPerformanceHighlights();
      final accuracy = await _statsDao.getOverallAccuracy();
      
      if (mounted) {
        setState(() {
          _masteryDistribution = mastery;
          _vocabGrowth = growth;
          _monthlyActivity = activity;
          _highlights = highlights;
          _retentionRate = accuracy.rate > 0 ? accuracy.rate : 0.85;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint("Error loading stats: $e");
      if (mounted) {
        setState(() {
          _isLoading = false; // Ensure we don't hang
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC), // Slight cool grey background
      appBar: AppBar(
        automaticallyImplyLeading: false,
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text('学习分析', style: GoogleFonts.notoSans(fontWeight: FontWeight.w900, color: AppColors.textHighEmphasis)),
        centerTitle: true,
      ),
      body: _isLoading 
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // 1. Mastery Distribution (Replaces Radar)
                  if (_masteryDistribution != null)
                     MasteryPieChart(distribution: _masteryDistribution!),
                  
                  const SizedBox(height: 20),
                  
                  // 2. Weekly Activity (Replaces Retention Line)
                  WeeklyBarChart(weeklyActivity: _monthlyActivity),
                  
                  const SizedBox(height: 20),
                  
                  const SizedBox(height: 20),
                  
                  // 4. Heatmap
                  StudyHeatMap(activity: _monthlyActivity),
                  
                  const SizedBox(height: 40),
                ],
              ),
            ),
    );
  }
}

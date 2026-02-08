
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/services/global_stats_notifier.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/database/daos/stats_dao.dart';
import '../../../../core/database/daos/user_stats_dao.dart';

import '../widgets/mastery_pie_chart.dart';
import '../widgets/study_heatmap.dart';
import '../widgets/weekly_bar_chart.dart';

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
  List<DailyActivity> _monthlyActivity = [];

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
      final activity = await _statsDao.getMonthlyActivity();
      
      if (mounted) {
        setState(() {
          _masteryDistribution = mastery;
          _monthlyActivity = activity;
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
          : LayoutBuilder(
              builder: (context, constraints) {
                if (constraints.maxWidth > 600) {
                  return _buildTabletLayout();
                }
                return _buildMobileLayout();
              },
            ),
    );
  }

  Widget _buildMobileLayout() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 1. Mastery Distribution
          if (_masteryDistribution != null)
             MasteryPieChart(distribution: _masteryDistribution!)
                .animate()
                .fadeIn(duration: 500.ms)
                .scale(delay: 100.ms),
          
          const SizedBox(height: 20),
          
          // 2. Weekly Activity
          WeeklyBarChart(weeklyActivity: _monthlyActivity)
              .animate()
              .fadeIn(duration: 500.ms, delay: 200.ms)
              .slideX(begin: 0.1, end: 0, curve: Curves.easeOutQuad),
          
          const SizedBox(height: 20),
          
          // 4. Heatmap
          StudyHeatMap(activity: _monthlyActivity)
              .animate()
              .fadeIn(duration: 500.ms, delay: 400.ms)
              .slideY(begin: 0.1, end: 0, curve: Curves.easeOutQuad),
          
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _buildTabletLayout() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(32),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Left Column (40%) - Mastery
          Expanded(
            flex: 4,
            child: Column(
              children: [
                if (_masteryDistribution != null)
                   MasteryPieChart(distribution: _masteryDistribution!)
                      .animate()
                      .fadeIn(duration: 500.ms)
                      .scale(delay: 100.ms),
              ],
            ),
          ),
          
          const SizedBox(width: 32),
          
          // Right Column (60%) - Activity & Heatmap
          Expanded(
            flex: 6,
            child: Column(
              children: [
                WeeklyBarChart(weeklyActivity: _monthlyActivity)
                    .animate()
                    .fadeIn(duration: 500.ms, delay: 200.ms)
                    .slideX(begin: 0.1, end: 0, curve: Curves.easeOutQuad),
                
                const SizedBox(height: 24),
                
                StudyHeatMap(activity: _monthlyActivity)
                    .animate()
                    .fadeIn(duration: 500.ms, delay: 400.ms)
                    .slideY(begin: 0.1, end: 0, curve: Curves.easeOutQuad),
                
                const SizedBox(height: 40),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

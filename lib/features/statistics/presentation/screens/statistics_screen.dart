import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/database/daos/stats_dao.dart';
import '../../../../core/database/daos/user_stats_dao.dart';
import '../../../../core/database/models/user_stats.dart';

class StatisticsScreen extends StatefulWidget {
  const StatisticsScreen({super.key});

  @override
  State<StatisticsScreen> createState() => _StatisticsScreenState();
}

class _StatisticsScreenState extends State<StatisticsScreen> {
  final StatsDao _statsDao = StatsDao();
  final UserStatsDao _userStatsDao = UserStatsDao();
  
  bool _isLoading = true;
  UserStats? _userStats;
  List<DailyActivity> _weeklyActivity = [];
  MasteryDistribution? _masteryDist;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final stats = await _userStatsDao.getUserStats();
    final activity = await _statsDao.getWeeklyActivity();
    final mastery = await _statsDao.getMasteryDistribution();

    if (mounted) {
      setState(() {
        _userStats = stats;
        _weeklyActivity = activity;
        _masteryDist = mastery;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('数据统计', style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
      ),
      body: _isLoading 
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildSummaryCards(),
                  const SizedBox(height: 24),
                  _buildWeeklyActivityChart(),
                  const SizedBox(height: 24),
                  _buildMasteryPieChart(),
                ],
              ),
            ),
    );
  }

  Widget _buildSummaryCards() {
    return Row(
      children: [
        Expanded(
          child: _buildStatCard(
            '🔥 连续打卡',
            '${_userStats?.continuousDays ?? 0}',
            '天',
            Colors.orange.shade50,
            Colors.orange,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _buildStatCard(
            '⏱️ 学习时长',
            '${(_userStats?.totalStudyMinutes ?? 0) ~/ 60}小时 ${(_userStats?.totalStudyMinutes ?? 0) % 60}分',
            '累计',
            Colors.blue.shade50,
            Colors.blue,
          ),
        ),
      ],
    );
  }

  Widget _buildStatCard(String title, String value, String unit, Color bgColor, Color accentColor) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade100),
        boxShadow: const [
           BoxShadow(
              color: AppColors.shadowWhite,
              offset: Offset(0, 4),
              blurRadius: 0,
            )
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold, color: AppColors.textMediumEmphasis)),
          const SizedBox(height: 8),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text(value, style: GoogleFonts.plusJakartaSans(fontSize: 24, fontWeight: FontWeight.w900, color: AppColors.textHighEmphasis)),
                const SizedBox(width: 4),
                Text(unit, style: GoogleFonts.plusJakartaSans(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.textMediumEmphasis)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWeeklyActivityChart() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
         border: Border.all(color: Colors.grey.shade100),
          boxShadow: const [
             BoxShadow(color: AppColors.shadowWhite, offset: Offset(0, 4), blurRadius: 0)
          ]
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('本周学习趋势', style: GoogleFonts.plusJakartaSans(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 24),
          SizedBox(
            height: 200,
            child: BarChart(
              BarChartData(
                alignment: BarChartAlignment.spaceAround,
                maxY: 20, // max expected for demo
                barTouchData: BarTouchData(enabled: false), // simplify for now
                titlesData: FlTitlesData(
                  show: true,
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (value, meta) {
                        // Assuming 0 is 6 days ago, 6 is today
                        const style = TextStyle(color: AppColors.textMediumEmphasis, fontWeight: FontWeight.bold, fontSize: 10);
                        String text = '';
                        switch (value.toInt()) {
                          case 0: text = '周一'; break;
                          case 1: text = '周二'; break;
                          case 2: text = '周三'; break;
                          case 3: text = '周四'; break;
                          case 4: text = '周五'; break;
                          case 5: text = '周六'; break;
                          case 6: text = '周日'; break;
                        }
                        return SideTitleWidget(axisSide: meta.axisSide, child: Text(text, style: style));
                      },
                    ),
                  ),
                  leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                ),
                gridData: const FlGridData(show: false),
                borderData: FlBorderData(show: false),
                barGroups: _weeklyActivity.asMap().entries.map((entry) {
                  return BarChartGroupData(
                    x: entry.key,
                    barRods: [
                      BarChartRodData(
                        toY: entry.value.count.toDouble(),
                        color: AppColors.primary,
                        width: 12,
                        borderRadius: BorderRadius.circular(4),
                        backDrawRodData: BackgroundBarChartRodData(
                            show: true, toY: 20, color: Colors.grey.shade100),
                      ),
                    ],
                  );
                }).toList(),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMasteryPieChart() {
    if (_masteryDist == null) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
         border: Border.all(color: Colors.grey.shade100),
          boxShadow: const [
             BoxShadow(color: AppColors.shadowWhite, offset: Offset(0, 4), blurRadius: 0)
          ]
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('单词掌握程度', style: GoogleFonts.plusJakartaSans(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 24),
          SizedBox(
            height: 200,
            child: Row(
              children: [
                Expanded(
                  child: PieChart(
                    PieChartData(
                      sectionsSpace: 4,
                      centerSpaceRadius: 40,
                      sections: [
                        PieChartSectionData(
                          color: Colors.grey.shade200,
                          value: _masteryDist!.newWords.toDouble(),
                          title: '',
                          radius: 20,
                        ),
                        PieChartSectionData(
                          color: AppColors.secondary,
                          value: _masteryDist!.learning.toDouble(),
                          title: '', // '${_masteryDist!.learning}',
                          radius: 30,
                          titleStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white)
                        ),
                        PieChartSectionData(
                          color: AppColors.primary,
                          value: _masteryDist!.mastered.toDouble(),
                          title: '', // '${_masteryDist!.mastered}',
                          radius: 40,
                          titleStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white)
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 24),
                Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildLegendItem(AppColors.primary, '已掌握', _masteryDist!.mastered),
                    const SizedBox(height: 8),
                    _buildLegendItem(AppColors.secondary, '学习中', _masteryDist!.learning),
                    const SizedBox(height: 8),
                    _buildLegendItem(Colors.grey.shade300, '未学习', _masteryDist!.newWords),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLegendItem(Color color, String label, int count) {
    return Row(
      children: [
        Container(width: 12, height: 12, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 8),
        Text(label, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: AppColors.textMediumEmphasis)),
        const SizedBox(width: 4),
        Text('($count)', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: AppColors.textHighEmphasis)),
      ],
    );
  }
}

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
  BookProgress? _bookProgress;
  AccuracyStats? _accuracyStats;
  List<VocabGrowthPoint> _vocabGrowth = [];
  MasteryDistribution? _masteryDist;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final stats = await _userStatsDao.getUserStats();
    
    // Determine bookId (Fallback to default convention if empty)
    String bookId = stats.currentBookId;
    if (bookId.isEmpty) {
      // Assuming standard ID format: waiyan_{grade}_{semester}
      // This is a temporary bridge for legacy state
      bookId = 'waiyan_${stats.currentGrade}_${stats.currentSemester}';
    }

    final bookProg = await _statsDao.getBookProgress(bookId);
    final accuracy = await _statsDao.getOverallAccuracy();
    final growth = await _statsDao.getVocabularyGrowth();
    final mastery = await _statsDao.getMasteryDistribution(bookId);

    if (mounted) {
      setState(() {
        _userStats = stats;
        _bookProgress = bookProg;
        _accuracyStats = accuracy;
        _vocabGrowth = growth;
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
                  _buildProgressAndAccuracyRow(),
                  const SizedBox(height: 24),
                  _buildVocabGrowthChart(),
                  const SizedBox(height: 24),
                  _buildMasteryPieChart(),
                ],
              ),
            ),
    );
  }

  Widget _buildProgressAndAccuracyRow() {
    return Row(
      children: [
        // Book Progress Card
        Expanded(
          flex: 3,
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
              boxShadow: [BoxShadow(color: AppColors.shadowWhite, offset: Offset(0, 8), blurRadius: 20)],
            ),
            child: Column(
               crossAxisAlignment: CrossAxisAlignment.start,
               children: [
                 Row(
                   children: [
                     Icon(Icons.book_rounded, color: AppColors.primary, size: 20),
                     const SizedBox(width: 8),
                     Text("本册进度", style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold, color: AppColors.textMediumEmphasis)),
                   ],
                 ),
                 const SizedBox(height: 16),
                 Text("${(_bookProgress?.percentage ?? 0 * 100).toStringAsFixed(1)}%", style: GoogleFonts.plusJakartaSans(fontSize: 32, fontWeight: FontWeight.w900, color: AppColors.textHighEmphasis)),
                 const SizedBox(height: 8),
                 LinearProgressIndicator(
                   value: _bookProgress?.percentage ?? 0,
                   backgroundColor: AppColors.primary.withOpacity(0.1),
                   color: AppColors.primary,
                   minHeight: 8,
                   borderRadius: BorderRadius.circular(4),
                 ),
                 const SizedBox(height: 8),
                 Text("${_bookProgress?.learned ?? 0} / ${_bookProgress?.total ?? 0} 词", style: TextStyle(color: AppColors.textMediumEmphasis, fontSize: 12)),
               ],
            ),
          ),
        ),
        const SizedBox(width: 16),
        // Accuracy Card
        Expanded(
          flex: 2,
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppColors.primary,
              borderRadius: BorderRadius.circular(24),
              boxShadow: [BoxShadow(color: AppColors.primary.withOpacity(0.3), offset: Offset(0, 8), blurRadius: 20)],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                 Row(
                   children: [
                     Icon(Icons.track_changes, color: Colors.white.withOpacity(0.8), size: 20),
                     const SizedBox(width: 8),
                     Text("正确率", style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold, color: Colors.white.withOpacity(0.8))),
                   ],
                 ),
                 const SizedBox(height: 16),
                 Text("${((_accuracyStats?.rate ?? 0) * 100).toInt()}%", style: GoogleFonts.plusJakartaSans(fontSize: 32, fontWeight: FontWeight.w900, color: Colors.white)),
                 const SizedBox(height: 8),
                 Text("保持专注!", style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 12)),
                 const SizedBox(height: 10), // fill space
              ],
            ),
          ),
        )
      ],
    );
  }

  Widget _buildVocabGrowthChart() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [BoxShadow(color: AppColors.shadowWhite, offset: Offset(0, 8), blurRadius: 20)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('词汇量增长', style: GoogleFonts.plusJakartaSans(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textHighEmphasis)),
          const SizedBox(height: 24),
          SizedBox(
            height: 200,
            child: LineChart(
              LineChartData(
                gridData: FlGridData(show: false),
                titlesData: FlTitlesData(
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 32,
                      interval: 1,
                      getTitlesWidget: (value, meta) {
                        int index = value.toInt();
                        if (index >= 0 && index < _vocabGrowth.length) {
                           return Padding(
                             padding: const EdgeInsets.only(top: 8.0),
                             child: Text(_vocabGrowth[index].date, style: const TextStyle(fontSize: 10, color: AppColors.textMediumEmphasis, fontWeight: FontWeight.bold)),
                           );
                        }
                        return const SizedBox();
                      },
                    ),
                  ),
                  leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                ),
                borderData: FlBorderData(show: false),
                lineBarsData: [
                  LineChartBarData(
                    spots: _vocabGrowth.asMap().entries.map((e) => FlSpot(e.key.toDouble(), e.value.totalWords.toDouble())).toList(),
                    isCurved: true,
                    color: AppColors.primary,
                    barWidth: 4,
                    isStrokeCapRound: true,
                    dotData: FlDotData(show: false),
                    belowBarData: BarAreaData(
                      show: true,
                      color: AppColors.primary.withOpacity(0.1),
                    ),
                  ),
                ],
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

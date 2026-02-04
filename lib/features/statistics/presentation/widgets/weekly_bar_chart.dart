import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/database/daos/stats_dao.dart';

class WeeklyBarChart extends StatelessWidget {
  final List<DailyActivity> weeklyActivity;

  const WeeklyBarChart({
    super.key, 
    required this.weeklyActivity,
  });

  @override
  Widget build(BuildContext context) {
    // We expect 7 days. If more, take last 7.
    final displayData = weeklyActivity.length > 7 
        ? weeklyActivity.sublist(weeklyActivity.length - 7) 
        : weeklyActivity;

    int maxCount = 0;
    for (var d in displayData) {
      if (d.count > maxCount) maxCount = d.count;
    }
    // minimal height
    if (maxCount < 10) maxCount = 10;
    final double maxY = (maxCount * 1.2).toDouble(); 

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(32),
        boxShadow: const [
          BoxShadow(
            color: AppColors.shadowWhite, 
            offset: Offset(0, 12), 
            blurRadius: 24
          )
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                   Container(
                     padding: const EdgeInsets.all(8),
                     decoration: const BoxDecoration(
                       color: AppColors.primary, // Using primary blue
                       shape: BoxShape.circle,
                     ),
                     child: const Icon(Icons.bar_chart_rounded, color: Colors.white, size: 20),
                   ),
                   const SizedBox(width: 12),
                     Text(
                       "本周学习", // Weekly Learning
                       style: GoogleFonts.notoSans(
                         fontSize: 20, 
                         fontWeight: FontWeight.w900, 
                         color: AppColors.textHighEmphasis
                       )
                     ),
                ],
              ),
              // Legend
              Row(
                children: [
                   _buildLegendDot(AppColors.primary, "新词"),
                   const SizedBox(width: 8),
                   _buildLegendDot(Color(0xFFFFC107), "复习"),
                ],
              )
            ],
          ),
          const SizedBox(height: 24),
          SizedBox(
            height: 180,
            child: BarChart(
              BarChartData(
                alignment: BarChartAlignment.spaceAround,
                maxY: maxY,
                barTouchData: BarTouchData(
                  enabled: true,
                  touchTooltipData: BarTouchTooltipData(
                    tooltipBgColor: Colors.black87,
                    tooltipPadding: const EdgeInsets.all(8),
                    tooltipRoundedRadius: 8,
                    getTooltipItem: (group, groupIndex, rod, rodIndex) {
                       final activity = displayData[groupIndex];
                       // rodIndex 0 is bottom (new), 1 is top (reviews) ? 
                       // Actually we only have 1 rod per group for stacked? 
                       // No, Stacked is 1 rod with multiple rodStackItems.
                       
                         return BarTooltipItem(
                           "${activity.date.split('-').last}日\n",
                           GoogleFonts.plusJakartaSans(
                             color: Colors.white70,
                             fontWeight: FontWeight.bold, 
                             fontSize: 14
                           ),
                           children: [
                             TextSpan(
                               text: "新词: ${activity.newCount}\n",
                               style: const TextStyle(color: Colors.lightBlueAccent, fontSize: 14)
                             ),
                             TextSpan(
                               text: "复习: ${activity.reviewCount}",
                               style: const TextStyle(color: Colors.amberAccent, fontSize: 14)
                             ),
                           ]
                         );
                    }
                  ),
                ),
                titlesData: FlTitlesData(
                  show: true,
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 30,
                      getTitlesWidget: (value, meta) {
                         final index = value.toInt();
                         if (index >= 0 && index < displayData.length) {
                            final dateParts = displayData[index].date.split('-');
                            // Assuming YYYY-MM-DD
                            if (dateParts.length >= 3) {
                               return Padding(
                                 padding: const EdgeInsets.only(top: 8.0),
                                 child: Text(
                                   "${int.parse(dateParts[1])}/${int.parse(dateParts[2])}",
                                   style: const TextStyle(
                                     color: AppColors.textMediumEmphasis, 
                                     fontSize: 12, 
                                     fontWeight: FontWeight.bold
                                   )
                                 ),
                               );
                            }
                         }
                         return const SizedBox();
                      }
                    )
                  ),
                  leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                ),
                gridData: FlGridData(show: false),
                borderData: FlBorderData(show: false),
                barGroups: displayData.asMap().entries.map((entry) {
                   final index = entry.key;
                   final data = entry.value;
                   
                   return BarChartGroupData(
                     x: index,
                     barRods: [
                       BarChartRodData(
                         toY: data.count.toDouble(),
                         color: Colors.transparent, // Background of whole rod
                         width: 16,
                         borderRadius: BorderRadius.circular(6),
                         rodStackItems: [
                            BarChartRodStackItem(0, data.newCount.toDouble(), AppColors.primary),
                            BarChartRodStackItem(data.newCount.toDouble(), (data.newCount + data.reviewCount).toDouble(), const Color(0xFFFFC107)),
                         ]
                       )
                     ]
                   );
                }).toList(),
              )
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLegendDot(Color color, String text) {
     return Row(
       children: [
         Container(
           width: 8, height: 8,
           decoration: BoxDecoration(color: color, shape: BoxShape.circle),
         ),
         const SizedBox(width: 4),
         Text(text, style: const TextStyle(fontSize: 12, color: AppColors.textMediumEmphasis, fontWeight: FontWeight.bold))
       ],
     );
  }
}

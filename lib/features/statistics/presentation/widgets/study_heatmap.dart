import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/database/daos/stats_dao.dart';

class StudyHeatMap extends StatelessWidget {
  final List<DailyActivity> activity;

  const StudyHeatMap({super.key, required this.activity});

  @override
  Widget build(BuildContext context) {
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
               Text(
                  "学习打卡",
                  style: GoogleFonts.notoSans(
                    fontSize: 20, 
                    fontWeight: FontWeight.w900, 
                    color: AppColors.textHighEmphasis
                  )
                ),
                Text(
                  "30 Days",
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 14, 
                    color: AppColors.textMediumEmphasis
                  )
                ),
            ],
          ),
          const SizedBox(height: 24),
          
          Wrap(
            spacing: 8,
            runSpacing: 8,
             children: activity.map((day) {
               return _buildDaySquare(day.count);
             }).toList(),
          ),
          
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Text("Less", style: GoogleFonts.plusJakartaSans(fontSize: 12, color: AppColors.textMediumEmphasis)),
              const SizedBox(width: 8),
              _buildLegendSquare(0),
              const SizedBox(width: 4),
              _buildLegendSquare(5),
              const SizedBox(width: 4),
              _buildLegendSquare(10),
              const SizedBox(width: 4),
              _buildLegendSquare(20),
              const SizedBox(width: 8),
              Text("More", style: GoogleFonts.plusJakartaSans(fontSize: 12, color: AppColors.textMediumEmphasis)),
            ],
          )
        ],
      ),
    );
  }

  Widget _buildDaySquare(int count) {
    return Container(
      width: 24, // 布局尺寸
      height: 24,
      decoration: BoxDecoration(
        color: _getColorForCount(count),
        borderRadius: BorderRadius.circular(6),
      ),
    );
  }
  
  Widget _buildLegendSquare(int count) {
      return Container(
      width: 10, 
      height: 10,
      decoration: BoxDecoration(
        color: _getColorForCount(count),
        borderRadius: BorderRadius.circular(2),
      ),
    );
  }

  Color _getColorForCount(int count) {
    if (count == 0) return Colors.grey.shade200;
    if (count < 5) return AppColors.primary.withValues(alpha: 0.3);
    if (count < 10) return AppColors.primary.withValues(alpha: 0.6);
    if (count < 20) return AppColors.primary;
    return const Color(0xFF1E40AF); // 配色
  }
}

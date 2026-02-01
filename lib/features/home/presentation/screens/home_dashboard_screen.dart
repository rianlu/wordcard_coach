import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/bubbly_button.dart';
import '../../../../core/database/daos/user_stats_dao.dart';
import '../../../../core/database/models/user_stats.dart';
import '../../../learning/presentation/screens/daily_learning_session_screen.dart';

class HomeDashboardScreen extends StatefulWidget {
  const HomeDashboardScreen({super.key});

  @override
  State<HomeDashboardScreen> createState() => _HomeDashboardScreenState();
}

class _HomeDashboardScreenState extends State<HomeDashboardScreen> {
  final UserStatsDao _userStatsDao = UserStatsDao();
  UserStats? _stats;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadStats();
  }

  Future<void> _loadStats() async {
    final stats = await _userStatsDao.getUserStats();
    if (mounted) {
      setState(() {
        _stats = stats;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 30),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 16), // Status bar padding/safe area
                  _buildHeader(),
                  const SizedBox(height: 16),
                  _buildDateBadge(),
                  const SizedBox(height: 16),
                  _buildStatsRow(),
                  const SizedBox(height: 24),
                  _buildDailyQuestSection(context),
                  const SizedBox(height: 24),
                  _buildAdventureLevel(),
                ],
              ),
            ),
    );
  }

  Widget _buildHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.primary, width: 2),
                color: AppColors.primary.withOpacity(0.1),
              ),
              child: const Icon(Icons.person, color: AppColors.primary),
            ),
            const SizedBox(width: 12),
            Text(
              '你好, ${_stats?.nickname ?? "Friend"}! 👋',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: AppColors.textHighEmphasis,
              ),
            ),
          ],
        ),
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: AppColors.primary.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.calendar_today, color: AppColors.primary, size: 20),
        )
      ],
    );
  }

  Widget _buildDateBadge() {
    // Ideally use real date formating
    final now = DateTime.now();
    // Simplified date string
    final dateStr = "${now.year}年${now.month}月${now.day}日"; 
    
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade100),
          boxShadow: const [
            BoxShadow(
              color: AppColors.shadowWhite,
              offset: Offset(0, 4),
              blurRadius: 0,
            )
          ]
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.today, color: AppColors.primary, size: 18),
            const SizedBox(width: 8),
            Text(
              dateStr,
              style: GoogleFonts.plusJakartaSans(
                fontWeight: FontWeight.bold,
                fontSize: 14,
                color: AppColors.textMediumEmphasis,
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatsRow() {
    return Row(
      children: [
        Expanded(child: _buildStatCard('🔥', '连续打卡', '${_stats?.continuousDays ?? 0} 天')),
        const SizedBox(width: 16),
        Expanded(child: _buildStatCard('📚', '已学单词', '${_stats?.totalWordsLearned ?? 0}')),
      ],
    );
  }

  Widget _buildStatCard(String emoji, String label, String value) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
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
          Row(
            children: [
              Text(emoji, style: const TextStyle(fontSize: 20)),
              const SizedBox(width: 8),
              Text(label, style: GoogleFonts.plusJakartaSans(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.textMediumEmphasis)),
            ],
          ),
          const SizedBox(height: 4),
          Text(value, style: GoogleFonts.plusJakartaSans(fontSize: 20, fontWeight: FontWeight.w900, color: AppColors.textHighEmphasis)),
        ],
      ),
    );
  }

  Widget _buildDailyQuestSection(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
         Text(
          '每日任务 🚀',
           style: GoogleFonts.plusJakartaSans(
             fontSize:20,
             fontWeight: FontWeight.w800,
             color: AppColors.textHighEmphasis,
           ),
        ),
        const SizedBox(height: 16),
        BubblyButton(
          onPressed: () {
             // Navigate to Daily Learning Session
             Navigator.push(
               context,
               MaterialPageRoute(builder: (context) => const DailyLearningSessionScreen()),
             );
          },
          color: AppColors.primary,
          shadowColor: AppColors.shadowBlue,
          padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 16),
          child: Column(
            children: [
              Container(
                 padding: const EdgeInsets.all(12),
                 decoration: BoxDecoration(
                   color: Colors.white.withOpacity(0.2),
                   shape: BoxShape.circle,
                 ),
                 child: const Icon(Icons.menu_book, color: Colors.white, size: 32),
              ),
              const SizedBox(height: 12),
              Text(
                '学习新单词',
                style: GoogleFonts.plusJakartaSans( 
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                  fontSize: 18,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '今天探索 10 个新单词！',
                textAlign: TextAlign.center,
                style: GoogleFonts.plusJakartaSans(
                  color: Colors.white70,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        BubblyButton(
          onPressed: () {
             // Let's send review to spelling for variety
             Navigator.pushNamed(context, '/practice/spelling');
          },
          color: AppColors.secondary,
          shadowColor: AppColors.shadowYellow,
          padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 16),
          child: Column(
            children: [
              Container(
                 padding: const EdgeInsets.all(12),
                 decoration: BoxDecoration(
                   color: Colors.black.withOpacity(0.1),
                   shape: BoxShape.circle,
                 ),
                 child: const Icon(Icons.style, color: Color(0xFF664400), size: 32),
              ),
              const SizedBox(height: 12),
              Text(
                '复习',
                style: GoogleFonts.plusJakartaSans(
                  color: const Color(0xFF664400),
                  fontWeight: FontWeight.w900,
                  fontSize: 18,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '保持记忆清晰！',
                textAlign: TextAlign.center,
                style: GoogleFonts.plusJakartaSans(
                  color: const Color(0xAA664400),
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildAdventureLevel() {
      // Mock progress
      return GestureDetector(
        onTap: () {
          Navigator.pushNamed(context, '/statistics');
        },
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
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
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                   Row(
                     children: [
                       const Text('冒险等级', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
                       const SizedBox(width: 8),
                       Icon(Icons.bar_chart, size: 18, color: AppColors.primary.withOpacity(0.5)),
                     ],
                   ),
                   Container(
                     padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                     decoration: BoxDecoration(
                       color: AppColors.primary.withOpacity(0.1),
                       borderRadius: BorderRadius.circular(12),
                     ),
                     child: Text('Lv. ${_stats?.currentGrade ?? 3}', style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold, fontSize: 12)),
                   ),
                ],
              ),
              const SizedBox(height: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: const LinearProgressIndicator(
                  value: 0.1, // Mock
                  minHeight: 16,
                  backgroundColor: Color(0xFFe5e7eb),
                  valueColor: AlwaysStoppedAnimation(AppColors.primary),
                ),
              ),
               const SizedBox(height: 8),
               const Row(
                 mainAxisAlignment: MainAxisAlignment.spaceBetween,
                 children: [
                   Text('距离下一级还需要 350 XP！', style: TextStyle(color: AppColors.textMediumEmphasis, fontSize: 12, fontWeight: FontWeight.bold)),
                   Text('查看统计 >', style: TextStyle(color: AppColors.primary, fontSize: 10, fontWeight: FontWeight.bold)),
                 ],
               ),
            ],
          ),
        ),
      );
  }

}

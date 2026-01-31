import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/bubbly_button.dart';

class HomeDashboardScreen extends StatelessWidget {
  const HomeDashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SingleChildScrollView(
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
                image: const DecorationImage(
                  // Placeholder for avatar
                  image: NetworkImage('https://lh3.googleusercontent.com/aida-public/AB6AXuD7azJzy4j5G02Qdmmzts3b6tTgdR9N9vqiFURk4fJCvGlLExMtgXmr13Dac81TtwTINUN6wMYfAw-pVAHJCxxFK3RZ0KP7IHuLyAMPiqzycWspwdzFj1LqqCoOIaX-Q_e1ayfmO5UbshiVsLraB27loKkkCqmD80QFOda58kyCPZg_kknmRaYPd120Jjtyez9bmQJxyUXLIUZxbVYtKCsq_WLy7oI0861WrodDPobyFvv_ZHNW2v3PIZFS85Y-aGH1zo0DF4QyMpM'),
                  fit: BoxFit.cover,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Text(
              'Hi, Alex! 👋',
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
              'MONDAY, OCT 21',
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
        Expanded(child: _buildStatCard('🔥', 'Streak', '5 Days')),
        const SizedBox(width: 16),
        Expanded(child: _buildStatCard('⭐', 'Stars', '1,240')),
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
              Text(label.toUpperCase(), style: GoogleFonts.plusJakartaSans(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.textMediumEmphasis)),
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
          '每日任务🚀',
           style: GoogleFonts.plusJakartaSans(
             fontSize:20,
             fontWeight: FontWeight.w800,
             color: AppColors.textHighEmphasis,
           ),
        ),
        const SizedBox(height: 16),
        BubblyButton(
          onPressed: () {
            // Navigate to Practice Selection
            Navigator.pushNamed(context, '/practice/spelling');
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
                'Learn New Words',
                style: GoogleFonts.plusJakartaSans( // 💡 使用 GoogleFonts 解决“字体细”
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                  fontSize: 18,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Discover 10 new words today!',
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
            // Review logic or Battle
             Navigator.pushNamed(context, '/battle/matching');
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
                'Review',
                style: GoogleFonts.plusJakartaSans(
                  color: const Color(0xFF664400),
                  fontWeight: FontWeight.w900,
                  fontSize: 18,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Keep your memory sharp!',
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
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Adventure Level', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
                 Container(
                   padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                   decoration: BoxDecoration(
                     color: AppColors.primary.withOpacity(0.1),
                     borderRadius: BorderRadius.circular(12),
                   ),
                   child: const Text('LVL 12', style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold, fontSize: 12)),
                 ),
              ],
            ),
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: const LinearProgressIndicator(
                value: 0.65,
                minHeight: 16,
                backgroundColor: Color(0xFFe5e7eb),
                valueColor: AlwaysStoppedAnimation(AppColors.primary),
              ),
            ),
             const SizedBox(height: 8),
             const Text('350 XP more to reach Level 13!', style: TextStyle(color: AppColors.textMediumEmphasis, fontSize: 12, fontWeight: FontWeight.bold)),
          ],
        ),
      );
  }

}

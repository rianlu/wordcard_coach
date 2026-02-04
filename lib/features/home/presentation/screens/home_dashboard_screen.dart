import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/bubbly_button.dart';
import 'package:flutter/services.dart';
import 'dart:convert';
import '../../../../core/database/daos/user_stats_dao.dart';
import '../../../../core/database/daos/stats_dao.dart';
import '../../../../core/database/models/user_stats.dart';
import '../../../learning/presentation/screens/daily_learning_session_screen.dart';
import '../../../practice/presentation/screens/review_session_screen.dart';

import '../../../../core/services/global_stats_notifier.dart';

class HomeDashboardScreen extends StatefulWidget {
  const HomeDashboardScreen({super.key});

  @override
  State<HomeDashboardScreen> createState() => _HomeDashboardScreenState();
}

class _HomeDashboardScreenState extends State<HomeDashboardScreen> {
  final UserStatsDao _userStatsDao = UserStatsDao();
  final StatsDao _statsDao = StatsDao();
  
  UserStats? _stats;
  BookProgress? _bookProgress;
  bool _isLoading = true;
  List<dynamic> _booksManifest = [];

  @override
  void initState() {
    super.initState();
    _loadStats();
    // Subscribe to global stats updates (e.g. nickname change, learning progress)
    GlobalStatsNotifier.instance.addListener(_loadStats);
  }

  @override
  void dispose() {
    GlobalStatsNotifier.instance.removeListener(_loadStats);
    super.dispose();
  }

  Future<void> _loadStats() async {
    final stats = await _userStatsDao.getUserStats();
    
    // Determine bookId (Fallback logic similar to StatisticsScreen)
    String bookId = stats.currentBookId;
    if (bookId.isEmpty) {
      bookId = 'waiyan_${stats.currentGrade}_${stats.currentSemester}';
    }

    // Fetch progress
    final bookProg = await _statsDao.getBookProgress(bookId);

    // Load manifest if needed
    if (_booksManifest.isEmpty) {
      try {
        final jsonStr = await rootBundle.loadString('assets/data/books_manifest.json');
        _booksManifest = jsonDecode(jsonStr);
      } catch (e) {
        // quiet error
      }
    }

    if (mounted) {
      setState(() {
        _stats = stats;
        _bookProgress = bookProg;
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
                  const SizedBox(height: 24),
                  _buildDailyQuestSection(context),
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
      ],
    );
  }


  Widget _buildCurrentBookCard() {
    final percentage = _bookProgress?.percentage ?? 0.0;
    final learned = _bookProgress?.learned ?? 0;
    final total = _bookProgress?.total ?? 0;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.grey.shade100),
        boxShadow: const [
           BoxShadow(
              color: AppColors.shadowWhite,
              offset: Offset(0, 8),
              blurRadius: 20,
            )
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.menu_book_rounded, color: AppColors.primary, size: 24),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '当前教材',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textMediumEmphasis,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _getCurrentBookName(),
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textHighEmphasis,
                        overflow: TextOverflow.ellipsis,
                      ),
                      maxLines: 1,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '总体进度',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey.shade600,
                ),
              ),
              Text(
                '${(percentage * 100).toStringAsFixed(1)}%',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                  color: AppColors.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: percentage,
              minHeight: 12,
              backgroundColor: AppColors.primary.withOpacity(0.1),
              valueColor: const AlwaysStoppedAnimation(AppColors.primary),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            '已掌握 $learned / $total 词',
            style: const TextStyle(
              fontSize: 12,
              color: AppColors.textMediumEmphasis,
            ),
          ),
        ],
      ),
    );
  }

  String _getCurrentBookName() {
    if (_stats == null) return '加载中...';
    
    // 1. Try to find by ID
    final bookId = _stats!.currentBookId;
    if (bookId.isNotEmpty && _booksManifest.isNotEmpty) {
      final book = _booksManifest.firstWhere(
        (b) => b['id'] == bookId, 
        orElse: () => null
      );
      if (book != null) {
        return book['name'] as String;
      }
    }
    
    // 2. Try to find by grade/semester (legacy fallback)
    if (_booksManifest.isNotEmpty) {
       final book = _booksManifest.firstWhere(
        (b) => b['grade'] == _stats!.currentGrade && b['semester'] == _stats!.currentSemester,
        orElse: () => null
      );
      if (book != null) {
        return book['name'] as String;
      }
    }
    
    // 3. Fallback
    return '${_stats!.currentGrade}年级 ${_stats!.currentSemester == 1 ? "上" : "下"}册';
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
          onPressed: () async {
             // Navigate to Daily Learning Session
             await Navigator.push(
               context,
               MaterialPageRoute(builder: (context) => const DailyLearningSessionScreen()),
             );
             
             // Refresh stats when returning
             if (mounted) _loadStats();
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
          onPressed: () async {
             await Navigator.push(
               context,
               MaterialPageRoute(builder: (context) => const ReviewSessionScreen()),
             );
             // Refresh stats when returning
             if (mounted) _loadStats();
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


}

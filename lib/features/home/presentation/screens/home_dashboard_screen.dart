import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/bubbly_button.dart';
import '../../../../core/widgets/animated_speaker_button.dart';
import 'package:flutter/services.dart';
import 'dart:ui' as ui;
import 'dart:convert';
import '../../../../core/database/daos/user_stats_dao.dart';
import '../../../../core/database/daos/stats_dao.dart';
import '../../../../core/database/models/user_stats.dart';
import '../../../../core/services/iciba_daily_service.dart';
import '../../../../core/services/audio_service.dart';
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
  DailySentence? _dailySentence;
  bool _isPlayingAudio = false;

  @override
  void initState() {
    super.initState();
    _loadStats();
    _loadQuote();
    // Subscribe to global stats updates (e.g. nickname change, learning progress)
    GlobalStatsNotifier.instance.addListener(_loadStats);
  }

  Future<void> _loadQuote() async {
    final sentence = await IcibaDailyService().getTodaySentence();
    if (mounted) {
      setState(() => _dailySentence = sentence);
    }
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
                  SizedBox(height: MediaQuery.of(context).padding.top),
                  _buildHeader(),
                  const SizedBox(height: 20),
                  if (_dailySentence != null) _buildDailySentenceCard(),
                  if (_dailySentence != null) const SizedBox(height: 20),
                  _buildDailyQuestSection(context),
                ],
              ),
            ),
    );
  }

  Future<void> _playDailyAudio() async {
    // Allow playing if we have a URL OR fallback text
    if (_isPlayingAudio || (_dailySentence?.audioUrl == null && _dailySentence?.englishContent == null)) return;
    
    setState(() => _isPlayingAudio = true);
    try {
      await AudioService().playUrl(
        _dailySentence!.audioUrl ?? "", // Pass empty string if null
        fallbackText: _dailySentence!.englishContent,
      );
    } finally {
      if (mounted) {
        await Future.delayed(const Duration(milliseconds: 100));
        if (mounted) setState(() => _isPlayingAudio = false);
      }
    }
  }

  /// Wavy/Stamp style daily sentence card
  Widget _buildDailySentenceCard() {
    return GestureDetector(
      onTap: _playDailyAudio,
      child: PhysicalShape(
        clipper: WavyClipper(),
        color: Colors.white,
        clipBehavior: Clip.antiAlias, // Ensure background image is clipped to waves
        elevation: 6,
        shadowColor: AppColors.primary.withOpacity(0.2),
        child: Stack(
          children: [
             // 1. Subtle Background Image
            if (_dailySentence?.imageUrl != null)
              Positioned.fill(
                child: Opacity(
                  opacity: 0.12,
                  child: Image.network(
                    _dailySentence!.imageUrl!,
                    fit: BoxFit.cover,
                    errorBuilder: (_,__,___) => const SizedBox(),
                  ),
                ),
              ),
            
            // 2. Content
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
              child: Column(
                mainAxisSize: MainAxisSize.min, // Ensure it doesn't try to take infinite height
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Badge
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: AppColors.secondary,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                         BoxShadow(
                          color: AppColors.secondary.withOpacity(0.3),
                          blurRadius: 6,
                          offset: const Offset(0, 3),
                        ),
                      ]
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                         const Icon(Icons.lightbulb_rounded, color: Colors.white, size: 14),
                         const SizedBox(width: 4),
                         Text(
                           'Daily Quote',
                           style: GoogleFonts.plusJakartaSans(
                             fontSize: 11,
                             fontWeight: FontWeight.w800,
                             color: Colors.white,
                           ),
                        ),
                      ],
                    ),
                  ),
                  
                  const SizedBox(height: 20),

                  // English (Main Focus)
                  Text(
                    _dailySentence!.englishContent,
                    textAlign: TextAlign.start,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 18, 
                      fontWeight: FontWeight.w800,
                      color: AppColors.textHighEmphasis,
                      height: 1.3,
                    ),
                  ),
                  
                  const SizedBox(height: 16),

                  // Footer: Chinese + Mini Play Button
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Expanded(
                        child: Text(
                          _dailySentence!.chineseNote,
                          style: GoogleFonts.notoSans(
                            fontSize: 13,
                            color: AppColors.textMediumEmphasis,
                            height: 1.4,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      // Mini Play Button
                      AnimatedSpeakerButton(
                         onPressed: _playDailyAudio,
                         isPlaying: _isPlayingAudio,
                         size: 20,
                         primaryColor: AppColors.secondary.withOpacity(0.8),
                         playingColor: AppColors.primary,
                      ),
                    ],
                  ),
                ],
              ),
            ),
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

class WavyClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    var path = Path();
    // Enhanced wave effect
    double waveHeight = 6.0; // Increased fro 4.0
    double frequency = 20.0; // Increased from 18.0

    path.moveTo(0, 0);

    // Top Edge
    for (double i = 0; i < size.width; i += frequency) {
      path.quadraticBezierTo(
        i + frequency / 2, waveHeight, 
        i + frequency, 0
      );
    }
    
    // Right Edge
    for (double i = 0; i < size.height; i += frequency) {
       path.quadraticBezierTo(
        size.width - waveHeight, i + frequency / 2, 
        size.width, i + frequency
      );
    }

    // Bottom Edge
    for (double i = size.width; i > 0; i -= frequency) {
        path.quadraticBezierTo(
        i - frequency / 2, size.height - waveHeight, 
        i - frequency, size.height
      );
    }

    // Left Edge
    for (double i = size.height; i > 0; i -= frequency) {
      path.quadraticBezierTo(
        waveHeight, i - frequency / 2, 
        0, i - frequency
      );
    }
    
    path.close();
    return path;
  }

  @override
  bool shouldReclip(CustomClipper<Path> oldClipper) => false;
}

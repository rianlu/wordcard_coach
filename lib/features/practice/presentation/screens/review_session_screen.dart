import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import 'package:google_fonts/google_fonts.dart';
import '../../../../core/database/daos/word_dao.dart';
import '../../../../core/database/daos/user_stats_dao.dart'; 
import '../../../../core/database/daos/stats_dao.dart';
import '../../../../core/database/models/word.dart';
import '../../../../core/theme/app_colors.dart';

import '../../../../core/widgets/bubbly_button.dart';
import '../../../../core/widgets/mesh_gradient_background.dart';
import '../widgets/speaking_practice_view.dart';
import '../widgets/spelling_practice_view.dart';
import '../widgets/word_selection_view.dart';
import '../../../../core/widgets/app_dialog.dart';

enum ReviewMode {
  speaking,
  spelling,
  selection, 
}

class ReviewSessionScreen extends StatefulWidget {
  const ReviewSessionScreen({super.key});

  @override
  State<ReviewSessionScreen> createState() => _ReviewSessionScreenState();
}

class _ReviewSessionScreenState extends State<ReviewSessionScreen> {
  final WordDao _wordDao = WordDao();
  final UserStatsDao _userStatsDao = UserStatsDao();
  
  // 说明：逻辑说明
  List<Word> _reviewWords = [];
  List<Word> _distractorPool = []; 
  List<ReviewMode> _modes = []; 
  bool _isLoading = true;
  int _currentIndex = 0;
  
  // 说明：逻辑说明
  bool _isCardFlyingOut = false;
  Offset _slideOffset = Offset.zero;

  @override
  void initState() {
    super.initState();
    _loadWords();
  }

  Future<void> _loadWords() async {
    final userStats = await _userStatsDao.getUserStats();
    String bookId = userStats.currentBookId;
    
    // 说明：逻辑说明
    final words = await _wordDao.getWordsDueForReview(
      20, 
      bookId: bookId, 
      grade: bookId.isEmpty ? userStats.currentGrade : null, 
      semester: bookId.isEmpty ? userStats.currentSemester : null
    );

    if (words.isEmpty) {
      if (mounted) setState(() { _isLoading = false; _reviewWords = []; });
      return;
    }

    final random = Random();
    final modes = List.generate(words.length, (index) {
      final r = random.nextInt(3); 
      return ReviewMode.values[r];
    });

    final distractors = await _wordDao.getRandomWords(20);

    if (mounted) {
      setState(() {
        _reviewWords = words;
        _modes = modes;
        _distractorPool = distractors;
        _isLoading = false;
      });
    }
  }

  // 说明：逻辑说明
  Future<void> _handleAnswer(int quality) async {
    final word = _reviewWords[_currentIndex];
    await _wordDao.updateReviewStats(word.id, quality);

    if (quality >= 1) { // 说明：逻辑说明
      _triggerNextAnimation();
    } else {
      // 错误 答案 - 编号
      // 说明：逻辑说明
      // 说明：逻辑说明
      _triggerNextAnimation();
    }
  }

  void _triggerNextAnimation() {
    setState(() {
      _isCardFlyingOut = true;
      // 说明：逻辑说明
      _slideOffset = const Offset(500, -200); 
    });

    Future.delayed(const Duration(milliseconds: 300), () {
      if (mounted) _next();
    });
  }

  void _next() {
    if (_currentIndex < _reviewWords.length - 1) {
      setState(() {
        _currentIndex++;
        _isCardFlyingOut = false;
        _slideOffset = Offset.zero;
      });
    } else {
      _finishSession();
    }
  }

  void _finishSession() async {
    try {
       await StatsDao().recordDailyActivity(
         newWords: 0,
         reviewWords: _reviewWords.length,
         correct: _reviewWords.length, 
         wrong: 0, 
         minutes: 5 
       );
    } catch (e) {
      debugPrint("Error saving review stats: $e");
    }

    if (!mounted) return;
    _showSummaryDialog();
  }



  void _showSummaryDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return AppDialog.success(
          title: "复习完成！",
          subtitle: "你复习了 ${_reviewWords.length} 个单词，继续保持！",
          primaryButtonText: "完成",
          onPrimaryPressed: () {
            Navigator.pop(context); // 说明：逻辑说明
            Navigator.pop(context); // 说明：逻辑说明
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (_reviewWords.isEmpty) {
      return _buildEmptyState();
    }
    
    // 说明：逻辑说明
    return Scaffold(
      body: Stack(
        children: [
          // 说明：逻辑说明
          const Positioned.fill(child: MeshGradientBackground()),
          
          // 说明：逻辑说明
          SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final isWide = constraints.maxWidth > 700;
                
                if (isWide) {
                  return _buildTabletLayout();
                } else {
                  return _buildMobileLayout();
                }
              },
            ),
          ),
          
          // 说明：逻辑说明
          Positioned(
            top: MediaQuery.of(context).padding.top + 10,
            left: 16,
            child: CircleAvatar(
              backgroundColor: Colors.white.withValues(alpha: 0.8),
              child: IconButton(
                icon: const Icon(Icons.close_rounded, color: Colors.black54),
                onPressed: () => Navigator.pop(context),
              ),
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildMobileLayout() {
    return Column(
      children: [
        // 说明：逻辑说明
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              _buildCircularProgress(),
            ],
          ),
        ),
        
        // 说明：逻辑说明
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "每日复习",
                  style: GoogleFonts.plusJakartaSans(fontSize: 24, fontWeight: FontWeight.w800, color: AppColors.textHighEmphasis),
                ),
                Text(
                  "清理今日单词卡片堆！",
                  style: GoogleFonts.plusJakartaSans(fontSize: 14, color: AppColors.textMediumEmphasis),
                ),
              ],
            ),
          ),
        ),
        
        const SizedBox(height: 20),
        
        // 说明：逻辑说明
        Expanded(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: _buildFocusStack(),
            ),
          ),
        ),
        
        const SizedBox(height: 48), // 说明：逻辑说明
      ],
    );
  }
  
  Widget _buildTabletLayout() {
    return Row(
      children: [
        // 说明：逻辑说明
        Expanded(
          flex: 4,
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Spacer(),
                 Text(
                  "每日复习",
                  style: GoogleFonts.plusJakartaSans(fontSize: 32, fontWeight: FontWeight.w900, color: AppColors.textHighEmphasis),
                ),
                const SizedBox(height: 8),
                Text(
                  "通过清理卡片堆来保持记忆清晰。",
                  style: GoogleFonts.plusJakartaSans(fontSize: 16, color: AppColors.textMediumEmphasis),
                ),
                const SizedBox(height: 48),
                
                // 说明：逻辑说明
                Center(child: _buildCircularProgress(size: 100, fontSize: 24)),
                
                const Spacer(),
              ],
            ),
          ),
        ),
        
        // 说明：逻辑说明
        Expanded(
          flex: 6,
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 500), // 说明：逻辑说明
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: _buildFocusStack(),
              ),
            ),
          ),
        ),
      ],
    );
  }
  
  Widget _buildCircularProgress({double size = 60, double fontSize = 14}) {
    final remaining = _reviewWords.length - _currentIndex;
    final progress = (_currentIndex) / _reviewWords.length;
    
    return Container(
      width: size, height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          SizedBox(
            width: size, height: size,
            child: CircularProgressIndicator(
              value: 1.0,
              strokeWidth: 6,
              color: Colors.grey.withValues(alpha: 0.1),
            ),
          ),
          SizedBox(
            width: size, height: size,
            child: CircularProgressIndicator(
              value: 1.0 - progress, // 说明：逻辑说明
              strokeWidth: 6,
              color: AppColors.primary,
              strokeCap: StrokeCap.round,
            ),
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                "$remaining",
                style: GoogleFonts.plusJakartaSans(fontSize: fontSize, fontWeight: FontWeight.w800, color: AppColors.primary),
              ),
              Text(
                "剩余",
                style: GoogleFonts.plusJakartaSans(fontSize: fontSize * 0.4, fontWeight: FontWeight.bold, color: AppColors.textMediumEmphasis),
              ),
            ],
          )
        ],
      ),
    );
  }

  Widget _buildFocusStack() {
    final remaining = _reviewWords.length - _currentIndex;
    
    return Stack(
      children: [
        // 说明：逻辑说明
        if (remaining > 2) _buildFakeCard(scale: 0.9, yOffset: 30, opacity: 0.3),
        if (remaining > 1) _buildFakeCard(scale: 0.95, yOffset: 15, opacity: 0.6),
        
        // 说明：逻辑说明
        AnimatedSlide(
          offset: _isCardFlyingOut ? _slideOffset : Offset.zero,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInBack,
          child: AnimatedOpacity(
            opacity: _isCardFlyingOut ? 0.0 : 1.0,
            duration: const Duration(milliseconds: 200),
            child: _buildActiveCard(),
          ),
        ),
      ],
    );
  }
  
  Widget _buildFakeCard({double scale = 1.0, double yOffset = 0.0, double opacity = 1.0}) {
    return Transform.scale(
      scale: scale,
      child: Transform.translate(
        offset: Offset(0, yOffset),
        child: Container(
          width: double.infinity,
          height: 600, // 说明：逻辑说明
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: opacity),
            borderRadius: BorderRadius.circular(32),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 20,
                offset: const Offset(0, 10),
              )
            ],
            // 说明：逻辑说明
            border: Border.all(color: Colors.white.withValues(alpha: 0.5 * opacity), width: 1),
          ),
        ),
      ),
    );
  }

  Widget _buildActiveCard() {
    final currentWord = _reviewWords[_currentIndex];
    final currentMode = _modes[_currentIndex];
    
    return Container(
      width: double.infinity,
      // 说明：逻辑说明
      constraints: const BoxConstraints(minHeight: 400), 
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(32),
        boxShadow: const [
          BoxShadow(
            color: AppColors.shadowWhite,
            blurRadius: 30,
            offset: Offset(0, 15)
          )
        ]
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(32),
        child: Padding(
          padding: const EdgeInsets.all(0),
          child: _buildPracticeView(currentWord, currentMode),
        ),
      ),
    );
  }

  Widget _buildPracticeView(Word word, ReviewMode mode) {
    switch (mode) {
      case ReviewMode.speaking:
        return SpeakingPracticeView(
          key: ValueKey("speak_${word.id}"),
          word: word,
          onCompleted: _handleAnswer, 
        );
      case ReviewMode.spelling:
        return SpellingPracticeView(
          key: ValueKey("spell_${word.id}"),
          word: word,
          onCompleted: _handleAnswer,
        );
      case ReviewMode.selection:
        return WordSelectionView(
          key: ValueKey("select_${word.id}"),
          word: word,
          options: _generateOptions(word),
          onCompleted: _handleAnswer,
        );
    }
  }

  List<Word> _generateOptions(Word correctWord) {
    if (_distractorPool.isEmpty) return [correctWord]; 
    final random = Random();
    final Set<Word> optionsSet = {correctWord};
    int attempts = 0;
    while (optionsSet.length < 4 && attempts < 50) {
      final w = _distractorPool[random.nextInt(_distractorPool.length)];
      if (w.id != correctWord.id) optionsSet.add(w);
      attempts++;
    }
    final list = optionsSet.toList();
    list.shuffle();
    return list;
  }
  
  Widget _buildEmptyState() {
     return Scaffold(
        backgroundColor: Colors.white,
        body: Stack(
          children: [
            const Positioned.fill(child: MeshGradientBackground()),
            Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                   Container(
                    padding: const EdgeInsets.all(32),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      boxShadow: [
                         BoxShadow(
                           color: AppColors.primary.withValues(alpha: 0.15),
                           blurRadius: 40,
                           offset: const Offset(0, 10)
                         )
                      ]
                    ),
                    child: const Icon(Icons.check_circle_rounded, size: 80, color: AppColors.primary),
                  ).animate().scale(duration: 600.ms, curve: Curves.elasticOut),
                  
                  const SizedBox(height: 32),
                  
                  Text(
                    "暂无复习任务", 
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 24, 
                      fontWeight: FontWeight.w800,
                      color: AppColors.textHighEmphasis
                    )
                  ),
                  const SizedBox(height: 12),
                  Text(
                    "休息一下，或者去学习新单词吧！",
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 14,
                      color: AppColors.textMediumEmphasis
                    ),
                  ),

                  const SizedBox(height: 48),

                  BubblyButton(
                    onPressed: () => Navigator.pop(context), 
                    color: Colors.white,
                    shadowColor: Colors.grey.shade200,
                    borderRadius: 20,
                    padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.arrow_back_rounded, color: AppColors.textHighEmphasis, size: 20),
                        const SizedBox(width: 8),
                        Text(
                          "返回首页",
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 16,
                            fontWeight: FontWeight.bold, // 说明：逻辑说明
                            color: AppColors.textHighEmphasis
                          )
                        ),
                      ],
                    ),
                  )
                ],
              ),
            ),
          ],
        ),
     );
  }
}

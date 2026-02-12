import 'dart:async';
import 'dart:math';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';

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
  
  // 逻辑处理
  List<Word> _reviewWords = [];
  List<Word> _distractorPool = []; 
  List<ReviewMode> _modes = []; 
  bool _isLoading = true;
  int _currentIndex = 0;
  int _correctCount = 0;
  int _wrongCount = 0;
  DateTime? _sessionStart;
  
  // 细节处理
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
    
    // 细节处理
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
        _sessionStart = DateTime.now();
      });
    }
  }

  int _mapQualityForMode(ReviewMode mode, int rawScore) {
    if (mode == ReviewMode.speaking) {
      if (rawScore >= 3) return 5;
      if (rawScore == 2) return 3;
      return 0;
    }
    return rawScore;
  }

  Future<void> _handleAnswer(ReviewMode mode, int rawScore) async {
    final quality = _mapQualityForMode(mode, rawScore);
    final word = _reviewWords[_currentIndex];
    await _wordDao.updateReviewStats(word.id, quality);

    if (quality >= 3) {
      _correctCount++;
      _triggerNextAnimation();
    } else {
      _wrongCount++;
      _triggerNextAnimation();
    }
  }

  void _triggerNextAnimation() {
    setState(() {
      _isCardFlyingOut = true;
      // 极简过渡：旧卡仅轻微左移，避免晃眼
      _slideOffset = const Offset(-0.08, 0);
    });

    Future.delayed(const Duration(milliseconds: 280), () {
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
       final start = _sessionStart ?? DateTime.now();
       final minutes = ((DateTime.now().difference(start).inSeconds) / 60).ceil();
       await StatsDao().recordDailyActivity(
         newWords: 0,
         reviewWords: _reviewWords.length,
         correct: _correctCount, 
         wrong: _wrongCount, 
         minutes: minutes == 0 ? 1 : minutes
       );
    } catch (e) {
      debugPrint("Error saving review stats: $e");
    }

    if (!mounted) return;
    _showSummaryDialog();
  }



  void _showSummaryDialog() {
    showGeneralDialog(
      context: context,
      barrierDismissible: false,
      barrierLabel: 'ReviewSummary',
      barrierColor: Colors.transparent,
      transitionDuration: const Duration(milliseconds: 180),
      pageBuilder: (context, animation, secondaryAnimation) {
        return BackdropFilter(
          filter: ui.ImageFilter.blur(sigmaX: 5.0, sigmaY: 5.0),
          child: Container(
            color: Colors.black.withValues(alpha: 0.08),
            child: Center(
              child: AppDialog(
                icon: Icons.check_circle_rounded,
                iconColor: const Color(0xFF664400),
                iconBackgroundColor: AppColors.secondary.withValues(alpha: 0.22),
                title: "复习完成！",
                subtitle: "你复习了 ${_reviewWords.length} 个单词，继续保持！",
                primaryButtonText: "完成",
                primaryButtonColor: const Color(0xFFB98A00),
                onPrimaryPressed: () {
                  Navigator.pop(context); // 关闭弹窗
                  Navigator.pop(context); // 返回上一页
                },
              ),
            ),
          ),
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
    
    // 细节处理
    return Scaffold(
      body: Stack(
        children: [
          // 细节处理
          const Positioned.fill(child: MeshGradientBackground()),
          
          // 细节处理
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
          
          // 细节处理
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
        // 细节处理
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              _buildCircularProgress(),
            ],
          ),
        ),
        
        // 细节处理
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
        
        // 细节处理
        Expanded(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: _buildFocusStack(),
            ),
          ),
        ),
        
        const SizedBox(height: 48), // 布局尺寸
      ],
    );
  }
  
  Widget _buildTabletLayout() {
    return Row(
      children: [
        // 细节处理
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
                
                // 逻辑处理
                Center(child: _buildCircularProgress(size: 100, fontSize: 24)),
                
                const Spacer(),
              ],
            ),
          ),
        ),
        
        // 细节处理
        Expanded(
          flex: 6,
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 500), // 细节处理
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
              value: 1.0 - progress, // 细节处理
              strokeWidth: 6,
              color: const Color(0xFFFFC107),
              strokeCap: StrokeCap.round,
            ),
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                "$remaining",
                style: GoogleFonts.plusJakartaSans(
                  fontSize: fontSize,
                  fontWeight: FontWeight.w800,
                  color: const Color(0xFF664400),
                ),
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
        // 细节处理
        if (remaining > 2) _buildFakeCard(scale: 0.9, yOffset: 30, opacity: 0.3),
        if (remaining > 1) _buildFakeCard(scale: 0.95, yOffset: 15, opacity: 0.6),
        
        // 细节处理
        AnimatedSlide(
          offset: _isCardFlyingOut ? _slideOffset : Offset.zero,
          duration: const Duration(milliseconds: 280),
          curve: Curves.easeInOutCubic,
          child: AnimatedOpacity(
            opacity: _isCardFlyingOut ? 0.0 : 1.0,
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOutCubic,
            child: TweenAnimationBuilder<double>(
            key: ValueKey('active_${_reviewWords[_currentIndex].id}_${_modes[_currentIndex].name}'),
            tween: Tween(begin: 0.0, end: 1.0),
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOutCubic,
            child: _buildActiveCard(),
            builder: (context, value, child) {
              return Opacity(
                opacity: value,
                child: child,
              );
            },
          ),
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
          height: 600, // 布局尺寸
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
            // 逻辑处理
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
      // 细节处理
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
          isReviewMode: true,
          onCompleted: (score) => _handleAnswer(mode, score), 
        );
      case ReviewMode.spelling:
        return SpellingPracticeView(
          key: ValueKey("spell_${word.id}"),
          word: word,
          isReviewMode: true,
          onCompleted: (score) => _handleAnswer(mode, score),
        );
      case ReviewMode.selection:
        return WordSelectionView(
          key: ValueKey("select_${word.id}"),
          word: word,
          options: _generateOptions(word),
          isReviewMode: true,
          onCompleted: (score) => _handleAnswer(mode, score),
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
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  Align(
                    alignment: Alignment.centerLeft,
                    child: CircleAvatar(
                      backgroundColor: Colors.white.withValues(alpha: 0.85),
                      child: IconButton(
                        icon: const Icon(Icons.close_rounded, color: Colors.black54),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ),
                  ),
                  const Spacer(),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 460),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(28),
                        boxShadow: const [
                          BoxShadow(
                            color: AppColors.shadowWhite,
                            blurRadius: 28,
                            offset: Offset(0, 12),
                          ),
                        ],
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(18),
                            decoration: BoxDecoration(
                              color: AppColors.secondary.withValues(alpha: 0.2),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.check_circle_rounded, size: 44, color: Color(0xFF664400)),
                          ),
                          const SizedBox(height: 18),
                          Text(
                            "今日复习已完成",
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 24,
                              fontWeight: FontWeight.w900,
                              color: AppColors.textHighEmphasis,
                            ),
                          ),
                          const SizedBox(height: 10),
                          Text(
                            "太好了，今天没有待复习单词。\n你可以继续学习新单词。",
                            textAlign: TextAlign.center,
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 14,
                              height: 1.5,
                              color: AppColors.textMediumEmphasis,
                            ),
                          ),
                          const SizedBox(height: 24),
                          SizedBox(
                            width: double.infinity,
                            child: BubblyButton(
                              onPressed: () => Navigator.pop(context),
                              color: AppColors.secondary,
                              shadowColor: AppColors.shadowYellow,
                              borderRadius: 16,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              child: Center(
                                child: Text(
                                  "返回首页",
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w800,
                                    color: const Color(0xFF664400),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const Spacer(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

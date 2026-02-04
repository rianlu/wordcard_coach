import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/database/daos/word_dao.dart';
import '../../../../core/database/daos/user_stats_dao.dart'; // For saving session result
import '../../../../core/database/daos/stats_dao.dart';
import '../../../../core/database/models/word.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/bubbly_button.dart';
import '../../../learning/presentation/widgets/word_learning_card.dart'; // Maybe reuse card style
// Practice Views
import '../widgets/speaking_practice_view.dart';
import '../widgets/spelling_practice_view.dart';
import '../widgets/word_selection_view.dart';

enum ReviewMode {
  speaking,
  spelling,
  selection, // Meaning selection
}

class ReviewSessionScreen extends StatefulWidget {
  const ReviewSessionScreen({super.key});

  @override
  State<ReviewSessionScreen> createState() => _ReviewSessionScreenState();
}

class _ReviewSessionScreenState extends State<ReviewSessionScreen> {
  final WordDao _wordDao = WordDao();
  final UserStatsDao _userStatsDao = UserStatsDao();
  
  List<Word> _reviewWords = [];
  List<Word> _distractorPool = []; // For selection mode
  List<ReviewMode> _modes = []; 
  bool _isLoading = true;
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    _loadWords();
  }

  Future<void> _loadWords() async {
    // Determine current book context
    final userStats = await _userStatsDao.getUserStats();
    String bookId = userStats.currentBookId;
    
    // Fetch up to 20 words for review
    // Fallback logic if filtering by book returns 0 but we want to review *anything*? 
    // Usually strictly review what's due.
    final words = await _wordDao.getWordsDueForReview(
      20, 
      bookId: bookId, 
      grade: bookId.isEmpty ? userStats.currentGrade : null, 
      semester: bookId.isEmpty ? userStats.currentSemester : null
    );

    if (words.isEmpty) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _reviewWords = [];
        });
      }
      return;
    }

    // Randomize modes
    final random = Random();
    final modes = List.generate(words.length, (index) {
      // Uniform distribution: 0, 1, 2
      final r = random.nextInt(3); 
      return ReviewMode.values[r];
    });

    // Load distractor pool (e.g. 20 random words)
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

  Future<void> _handleSuccess(int quality) async {
    final word = _reviewWords[_currentIndex];
    
    // Quality passed directly from views:
    // 5 = Perfect
    // 3 = Passable (Hint used or Retry)
    // 0 = Fail (Skip or Give up)
    
    await _wordDao.updateReviewStats(word.id, quality);
    
    _next();
  }
  
  void _next() {
    if (_currentIndex < _reviewWords.length - 1) {
      setState(() {
        _currentIndex++;
      });
    } else {
      _finishSession();
    }
  }

  void _finishSession() async {
    // 1. Record Stats
    try {
       await StatsDao().recordDailyActivity(
         newWords: 0,
         reviewWords: _reviewWords.length,
         correct: _reviewWords.length, // Simplified: Assume all practiced
         wrong: 0, 
         minutes: 5 // Mock duration
       );
    } catch (e) {
      debugPrint("Error saving review stats: $e");
    }

    // 2. Show summary
    if (!mounted) return;
    // 2. Show summary
    if (!mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 450),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(32),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(32),
                boxShadow: const [
                  BoxShadow(color: AppColors.shadowWhite, offset: Offset(0, 10), blurRadius: 40)
                ]
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Success/Review Icon
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEFF6FF), // Blue 50
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(color: const Color(0xFFDBEAFE).withOpacity(0.5), blurRadius: 20, spreadRadius: 5)
                      ]
                    ),
                    child: const Icon(Icons.verified_rounded, size: 64, color: AppColors.primary), // Blue
                  ),
                  const SizedBox(height: 32),
                  
                  Text(
                    "复习完成!", 
                    textAlign: TextAlign.center,
                    style: GoogleFonts.plusJakartaSans(fontSize: 28, fontWeight: FontWeight.w900, color: AppColors.textHighEmphasis)
                  ),
                  const SizedBox(height: 8),
                  Text(
                    "温故而知新，你今天巩固了 ${_reviewWords.length} 个单词。",
                    textAlign: TextAlign.center,
                    style: GoogleFonts.plusJakartaSans(fontSize: 16, color: AppColors.textMediumEmphasis, height: 1.5)
                  ),

                  const SizedBox(height: 32),

                  // Stats Row
                  Row(
                    children: [
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          decoration: BoxDecoration(
                            color: AppColors.background,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: Colors.grey.shade100)
                          ),
                          child: Column(
                            children: [
                              Text("${_reviewWords.length}", style: GoogleFonts.plusJakartaSans(fontSize: 24, fontWeight: FontWeight.bold, color: AppColors.primary)),
                              Text("复习单词", style: GoogleFonts.plusJakartaSans(fontSize: 12, color: AppColors.textMediumEmphasis)),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          decoration: BoxDecoration(
                            color: AppColors.background,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: Colors.grey.shade100)
                          ),
                          child: Column(
                            children: [
                              Text("+${_reviewWords.length * 5}", style: GoogleFonts.plusJakartaSans(fontSize: 24, fontWeight: FontWeight.bold, color: AppColors.secondary)),
                              Text("获得经验", style: GoogleFonts.plusJakartaSans(fontSize: 12, color: AppColors.textMediumEmphasis)),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 32),
                  
                  // Action Button
                  BubblyButton(
                    onPressed: () {
                       Navigator.pop(context); // Close dialog
                       Navigator.pop(context); // Exit session
                    },
                    color: AppColors.primary,
                    shadowColor: const Color(0xFF1565C0),
                    borderRadius: 20,
                    padding: const EdgeInsets.symmetric(vertical: 20),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          "完成",
                          style: GoogleFonts.plusJakartaSans(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)
                        ),
                        const SizedBox(width: 8),
                        const Icon(Icons.check_rounded, color: Colors.white, size: 20)
                      ],
                    ),
                  )
                ],
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
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (_reviewWords.isEmpty) {
      return Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.close_rounded, color: AppColors.textMediumEmphasis),
            onPressed: () => Navigator.pop(context),
          ),
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Illustration / Icon
                Container(
                  padding: const EdgeInsets.all(32),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF0FDF4), // Green 50
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(color: const Color(0xFFDCFCE7).withOpacity(0.5), blurRadius: 30, spreadRadius: 10)
                    ]
                  ),
                  child: const Icon(Icons.check_circle_rounded, size: 80, color: Color(0xFF22C55E)), // Green 500
                ),
                
                const SizedBox(height: 32),
                
                Text(
                  "暂无待复习单词",
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 24, 
                    fontWeight: FontWeight.w900, 
                    color: AppColors.textHighEmphasis
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  "完美！你已经完成了所有的复习任务。\n快去探索更多新内容吧。",
                  textAlign: TextAlign.center,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 16, 
                    color: AppColors.textMediumEmphasis,
                    height: 1.6
                  ),
                ),
                
                const SizedBox(height: 48),
                
                // Button
                SizedBox(
                  width: 220, // Premium fixed width
                  child: BubblyButton(
                    onPressed: () => Navigator.pop(context),
                    color: AppColors.primary,
                    shadowColor: const Color(0xFF1565C0),
                    borderRadius: 20,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    child: Center(
                      child: Text(
                        "返回主页",
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 18, 
                          fontWeight: FontWeight.bold, 
                          color: Colors.white
                        ),
                      ),
                    ),
                  ),
                )
              ],
            ),
          ),
        ),
      );
    }

    final currentWord = _reviewWords[_currentIndex];
    final currentMode = _modes[_currentIndex];
    final progress = (_currentIndex + 1) / _reviewWords.length;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text("Boss 对战 (${_currentIndex + 1}/${_reviewWords.length})"),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(6),
          child: LinearProgressIndicator(
            value: progress,
            backgroundColor: Colors.grey.shade200,
            valueColor: const AlwaysStoppedAnimation(AppColors.primary),
            minHeight: 6,
          ),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
             children: [
               Expanded(
                 child: _buildPracticeView(currentWord, currentMode),
               ),
             ],
          ),
        ),
      ),
    );
  }

  Widget _buildPracticeView(Word word, ReviewMode mode) {
    // We need to verify the signatures of these Views.
    // Assuming they take `word` and `onComplete`.
    
    switch (mode) {
      case ReviewMode.speaking:
        return SpeakingPracticeView(
          key: ValueKey(word.id),
          word: word,
          onCompleted: _handleSuccess, 
        );
      case ReviewMode.spelling:
        return SpellingPracticeView(
          key: ValueKey(word.id),
          word: word,
          onCompleted: _handleSuccess,
        );
      case ReviewMode.selection:
        // Generate options: Correct + 3 Distractors
        final options = _generateOptions(word);
        return WordSelectionView(
          key: ValueKey(word.id),
          word: word,
          options: options,
          onCompleted: _handleSuccess,
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
      if (w.id != correctWord.id) {
        optionsSet.add(w);
      }
      attempts++;
    }
    
    final list = optionsSet.toList();
    list.shuffle();
    return list;
  }
}

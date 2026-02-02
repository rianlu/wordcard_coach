import 'dart:math';
import 'package:flutter/material.dart';
import '../../../../core/database/daos/word_dao.dart';
import '../../../../core/database/daos/user_stats_dao.dart'; // For saving session result
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

  Future<void> _handleSuccess(bool isCorrect) async {
    final word = _reviewWords[_currentIndex];
    
    // SM-2 Scoring:
    // Correct = 5 (Perfect)
    // Wrong/Skip = 0 (Fail)
    // Passable = 3 (Hint used - if we had it)
    
    // Currently our views call this on "Completion", which implies success for Spelling/Speaking unless skipped.
    // But Speaking/Spelling views only call onCompleted() when correct (or skipped).
    // Let's refine:
    // If isCorrect is true => 5
    // If isCorrect is false (means skipped/wrong) => 0
    
    int quality = isCorrect ? 5 : 0;
    
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

  void _finishSession() {
    // Show summary
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text("复习完成！"),
        content: Text("本次复习 completed ${_reviewWords.length} words."),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context); // Close dialog
              Navigator.pop(context); // Close screen
            },
            child: const Text("太棒了"),
          )
        ],
      ),
    );
     // TODO: Save results to DB
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
        appBar: AppBar(title: const Text("复习")),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.check_circle_outline, size: 80, color: Colors.green),
              const SizedBox(height: 16),
              const Text("没有待复习的单词！", style: TextStyle(fontSize: 18)),
              const SizedBox(height: 8),
              const Text("去学习新单词吧。", style: TextStyle(color: Colors.grey)),
              const SizedBox(height: 24),
              BubblyButton(
                onPressed: () => Navigator.pop(context),
                color: AppColors.primary,
                child: const Text("返回", style: TextStyle(color: Colors.white)),
              )
            ],
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
          word: word,
          onCompleted: _handleSuccess, 
        );
      case ReviewMode.spelling:
        return SpellingPracticeView(
          word: word,
          onCompleted: _handleSuccess,
        );
      case ReviewMode.selection:
        // Generate options: Correct + 3 Distractors
        final options = _generateOptions(word);
        return WordSelectionView(
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

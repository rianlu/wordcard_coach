import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/database/daos/word_dao.dart';
import '../../../../core/database/daos/user_stats_dao.dart';
import '../../../../core/database/models/word.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/services/audio_service.dart';
import '../../../../core/widgets/bubbly_button.dart';
import '../widgets/word_learning_card.dart';
import '../../../practice/presentation/widgets/speaking_practice_view.dart';
import '../../../practice/presentation/widgets/word_selection_view.dart';
import '../../../practice/presentation/widgets/spelling_practice_view.dart';

enum SessionPhase {
  learning,
  speaking,
  selection,
  spelling,
  completed
}

class DailyLearningSessionScreen extends StatefulWidget {
  const DailyLearningSessionScreen({super.key});

  @override
  State<DailyLearningSessionScreen> createState() => _DailyLearningSessionScreenState();
}

class _DailyLearningSessionScreenState extends State<DailyLearningSessionScreen> {
  final WordDao _wordDao = WordDao();
  final UserStatsDao _userStatsDao = UserStatsDao();
  
  List<Word> _sessionWords = [];
  bool _isLoading = true;
  
  SessionPhase _currentPhase = SessionPhase.learning;
  int _currentIndex = 0;
  
  // Transition State
  bool _isTransitioning = false;
  int _transitionCountdown = 3;
  SessionPhase? _pendingNextPhase;

  @override
  void initState() {
    super.initState();
    _startSession();
  }

  @override
  void dispose() {
    AudioService().stop();
    super.dispose();
  }

  Future<void> _startSession() async {
    setState(() => _isLoading = true);
    try {
      final stats = await _userStatsDao.getUserStats();
      // Fetch 10 new words for today's session
      final words = await _wordDao.getNewWords(
        10, 
        grade: stats.currentGrade,
        semester: stats.currentSemester
      );
      
      if (mounted) {
        setState(() {
          _sessionWords = words;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint("Error starting session: $e");
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _next() {
    if (_currentIndex < _sessionWords.length - 1) {
      setState(() {
        _currentIndex++;
      });
    } else {
      // Phase completed, move to next phase
      _triggerPhaseTransition();
    }
  }

  void _triggerPhaseTransition() {
    // Determine next phase first
    AudioService().stop(); // Stop any playing audio
    SessionPhase next;
    switch (_currentPhase) {
        case SessionPhase.learning: next = SessionPhase.speaking; break;
        case SessionPhase.speaking: next = SessionPhase.selection; break;
        case SessionPhase.selection: next = SessionPhase.spelling; break;
        case SessionPhase.spelling: next = SessionPhase.completed; break;
        case SessionPhase.completed: next = SessionPhase.completed; break;
    }
    
    if (next == SessionPhase.completed) {
       _advancePhase(next);
       return;
    }

    // Start Transition Sequence
    setState(() {
      _isTransitioning = true;
      _transitionCountdown = 3;
      _pendingNextPhase = next;
    });

    _runTransitionCountdown(next);
  }

  void _runTransitionCountdown(SessionPhase nextPhase) async {
     for (int i = 3; i > 0; i--) {
       if (!mounted) return;
       setState(() => _transitionCountdown = i);
       await Future.delayed(const Duration(seconds: 1));
     }

     if (mounted) {
       setState(() {
         _isTransitioning = false;
         _pendingNextPhase = null;
       });
       _advancePhase(nextPhase);
     }
  }

  void _advancePhase(SessionPhase nextPhase) {
    setState(() {
      _currentIndex = 0;
      _currentPhase = nextPhase;
    });

    if (_currentPhase == SessionPhase.completed) {
       _handleSessionCompletion();
    }
  }
  
  Future<void> _handleSessionCompletion() async {
     await _saveProgress();
     if (mounted) _showCompletionDialog();
  }

  Future<void> _saveProgress() async {
    try {
       // 1. Mark words as learned
       await _wordDao.batchMarkAsLearned(_sessionWords);
       
       // 2. Update User Stats
       final stats = await _userStatsDao.getUserStats();
       final now = DateTime.now();
       final todayStr = "${now.year}-${now.month}-${now.day}";
       
       bool isNewDay = stats.lastStudyDate != todayStr;
       
       final newStats = stats.copyWith(
         totalWordsLearned: stats.totalWordsLearned + _sessionWords.length,
         totalStudyDays: isNewDay ? stats.totalStudyDays + 1 : stats.totalStudyDays,
         continuousDays: isNewDay ? stats.continuousDays + 1 : stats.continuousDays,
         lastStudyDate: todayStr,
         updatedAt: now.millisecondsSinceEpoch
       );
       
       await _userStatsDao.updateUserStats(newStats);
       
       debugPrint("Progress Saved: ${_sessionWords.length} words.");
    } catch (e) {
      debugPrint("Error saving progress: $e");
    }
  }

  void _showCompletionDialog() {
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
                  // Success Icon
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF0FDF4), // Green 50
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(color: const Color(0xFFDCFCE7).withOpacity(0.5), blurRadius: 20, spreadRadius: 5)
                      ]
                    ),
                    child: const Icon(Icons.emoji_events_rounded, size: 64, color: Color(0xFF22C55E)), // Green 500
                  ),
                  const SizedBox(height: 32),
                  
                  Text(
                    "任务完成!", 
                    textAlign: TextAlign.center,
                    style: GoogleFonts.plusJakartaSans(fontSize: 28, fontWeight: FontWeight.w900, color: AppColors.textHighEmphasis)
                  ),
                  const SizedBox(height: 8),
                  Text(
                    "太棒了！你完成了今天的学习任务。",
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
                              Text("${_sessionWords.length}", style: GoogleFonts.plusJakartaSans(fontSize: 24, fontWeight: FontWeight.bold, color: AppColors.primary)),
                              Text("新学单词", style: GoogleFonts.plusJakartaSans(fontSize: 12, color: AppColors.textMediumEmphasis)),
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
                              Text("+${_sessionWords.length * 10}", style: GoogleFonts.plusJakartaSans(fontSize: 24, fontWeight: FontWeight.bold, color: AppColors.secondary)),
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
                          "继续",
                          style: GoogleFonts.plusJakartaSans(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)
                        ),
                        const SizedBox(width: 8),
                        const Icon(Icons.arrow_forward_rounded, color: Colors.white, size: 20)
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

  String _getPhaseTitle(SessionPhase phase) {
    switch (phase) {
      case SessionPhase.learning: return "学习阶段 (Learning)";
      case SessionPhase.speaking: return "口语练习 (Speaking)";
      case SessionPhase.selection: return "词义辨析 (Selection)";
      case SessionPhase.spelling: return "拼写练习 (Spelling)";
      case SessionPhase.completed: return "Completed";
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: AppColors.background,
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (_sessionWords.isEmpty) {
      return Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text("该等级暂时没有新单词了!"),
              TextButton(onPressed: () => Navigator.pop(context), child: const Text("返回"))
            ],
          ),
        ),
      );
    }

    if (_currentPhase == SessionPhase.completed) {
      return const Scaffold(
        backgroundColor: AppColors.background,
        body: Center(child: CircularProgressIndicator()), // Waiting for dialog
      );
    }

    final double progress = (_currentIndex + 1) / _sessionWords.length;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(_getPhaseTitle(_currentPhase), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        centerTitle: true,
        backgroundColor: AppColors.background,
        elevation: 0,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(6.0),
          child: LinearProgressIndicator(
            value: progress,
            backgroundColor: AppColors.primary.withOpacity(0.1),
            valueColor: const AlwaysStoppedAnimation<Color>(AppColors.primary),
            minHeight: 4,
          ),
        )
      ),
      body: Stack(
        children: [
          _buildCurrentView(),
          
          if (_isTransitioning)
            Positioned.fill(
              child: Container(
                color: Colors.white,
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        "下一项: ${_getPhaseTitle(_pendingNextPhase!)}",
                        style: GoogleFonts.plusJakartaSans(fontSize: 24, fontWeight: FontWeight.bold, color: AppColors.textMediumEmphasis)
                      ),
                      const SizedBox(height: 32),
                      Container(
                        width: 120, height: 120,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: AppColors.primary,
                          boxShadow: [BoxShadow(color: AppColors.primary.withOpacity(0.4), blurRadius: 40, offset: const Offset(0, 10))]
                        ),
                        child: Text(
                          "$_transitionCountdown",
                          style: GoogleFonts.plusJakartaSans(fontSize: 64, fontWeight: FontWeight.w900, color: Colors.white),
                        ),
                      ),
                      const SizedBox(height: 32),
                      Text("准备开始!", style: GoogleFonts.plusJakartaSans(fontSize: 18, color: AppColors.textMediumEmphasis)),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildCurrentView() {
    final word = _sessionWords[_currentIndex];

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 300),
      child: KeyedSubtree(
        key: ValueKey("${_currentPhase}_${word.id}"), // Ensure state reset
        child: _buildPhaseContent(word),
      )
    );
  }

  Widget _buildPhaseContent(Word word) {
    switch (_currentPhase) {
      case SessionPhase.learning:
        return WordLearningCard(
          word: word,
          onNext: _next,
        );
      case SessionPhase.speaking:
        return SpeakingPracticeView(
          word: word,
          onCompleted: (_) => _next(),
        );
      case SessionPhase.selection:
        final distractors = List<Word>.from(_sessionWords)..removeWhere((w) => w.id == word.id);
        distractors.shuffle();
        final options = (distractors.take(3).toList() + [word])..shuffle();
        
        return WordSelectionView(
          word: word,
          options: options,
          onCompleted: (_) => _next(),
        );
      case SessionPhase.spelling:
        return SpellingPracticeView(
          word: word,
          onCompleted: (_) => _next(),
        );
      default:
        return const SizedBox();
    }
  }
}

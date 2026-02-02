import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/database/daos/word_dao.dart';
import '../../../../core/database/daos/user_stats_dao.dart';
import '../../../../core/database/models/word.dart';
import '../../../../core/theme/app_colors.dart';
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
      // Phase completed, move to next phase
      _triggerPhaseTransition();
    }
  }

  void _triggerPhaseTransition() {
    // Determine next phase first
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
       // Optional: Play a "tick" sound here if desired, but user said no header TTS.
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
       // Maybe show a dedicated completion screen or dialog
       _showCompletionDialog();
    } else {
      // Show an interstitial or just transition? 
      // User might want to know they are entering a new phase.
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Starting ${_getPhaseTitle(_currentPhase)}!"), 
          backgroundColor: AppColors.primary,
          duration: const Duration(seconds: 2),
        )
      );
    }
  }
  
  void _showCompletionDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return AlertDialog(
          title: const Text("Session Completed!"),
          content: const Text("You have successfully learned 10 new words today."),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context); // Close dialog
                Navigator.pop(context); // Exit session
              },
              child: const Text("Awesome!"),
            )
          ],
        );
      }
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
              const Text("No new words available for this grade!"),
              TextButton(onPressed: () => Navigator.pop(context), child: const Text("Go Back"))
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
                        // Show "Next: Speaking" etc
                        "Next: ${_getPhaseTitle(_pendingNextPhase!)}",
                        style: GoogleFonts.plusJakartaSans(fontSize: 24, fontWeight: FontWeight.bold, color: AppColors.textMediumEmphasis)
                      ),
                      const SizedBox(height: 32),
                      Container(
                        width: 120, height: 120,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: AppColors.primary,
                          boxShadow: [BoxShadow(color: AppColors.primary.withOpacity(0.4), blurRadius: 40, offset: Offset(0, 10))]
                        ),
                        child: Text(
                          "$_transitionCountdown",
                          style: GoogleFonts.plusJakartaSans(fontSize: 64, fontWeight: FontWeight.w900, color: Colors.white),
                        ),
                      ),
                      const SizedBox(height: 32),
                      Text("Get Ready!", style: GoogleFonts.plusJakartaSans(fontSize: 18, color: AppColors.textMediumEmphasis)),
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

    // Animation switcher could be nice here
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
          onCompleted: _next,
        );
      case SessionPhase.selection:
        // Generate distractors
        // Ideally we should pre-fetch them or fetch async. 
        // For simplicity let's pick 3 random words from session words (excluding current) + maybe incomplete logic.
        // Actually picking from _sessionWords is risky if less than 4 words total.
        // Let's create a wrapper that handles distractors if we want to fetch more, 
        // OR just simple logic: use other session words as distractors.
        final distractors = List<Word>.from(_sessionWords)..removeWhere((w) => w.id == word.id);
        distractors.shuffle();
        final options = (distractors.take(3).toList() + [word])..shuffle();
        
        return WordSelectionView(
          word: word,
          options: options,
          onCompleted: _next,
        );
      case SessionPhase.spelling:
        return SpellingPracticeView(
          word: word,
          onCompleted: _next,
        );
      default:
        return const SizedBox();
    }
  }
}

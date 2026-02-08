import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/database/models/word.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/services/audio_service.dart';
import '../../../../core/services/speech_service.dart';
import '../../../../core/utils/phonetic_utils.dart';
import '../../../../core/widgets/animated_speaker_button.dart';
import 'package:flutter_animate/flutter_animate.dart';


import 'practice_success_overlay.dart';

/// Speaking practice state machine
enum SpeakingState { 
  idle,          // Initial state
  playingAudio,  // Playing standard pronunciation
  listening,     // Actively listening for user speech
  processing,    // Processing recognition result
  success,       // Successfully matched
  failed         // Failed to match (will retry or skip)
}

class SpeakingPracticeView extends StatefulWidget {
  final Word word;
  final Function(int score) onCompleted;

  const SpeakingPracticeView({
    super.key, 
    required this.word, 
    required this.onCompleted,
  });

  @override
  State<SpeakingPracticeView> createState() => _SpeakingPracticeViewState();
}

class _SpeakingPracticeViewState extends State<SpeakingPracticeView> with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  
  // Simplified state management
  SpeakingState _state = SpeakingState.idle;
  String _lastHeard = '';
  int _retryCount = 0;

  
  // Timers
  Timer? _skipTimer;
  Timer? _listenTimeoutTimer;
  Timer? _successTimer;
  StreamSubscription<bool>? _listeningSubscription;
  
  // Configuration
  static const int _maxRetries = 3;
  static const int _skipButtonDelaySeconds = 3;
  static const int _listenTimeoutSeconds = 8;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    );
    
    // Subscribe to mic state for UI feedback
    _listeningSubscription = SpeechService().listeningState.listen((isActive) {
      if (mounted && _state == SpeakingState.listening) {
        if (isActive) {
          // Visual feedback when mic actually activates
          AudioService().playAsset('mic_start.mp3');
        } else {
          // Mic stopped actively listening
          // If we are still in 'listening' state, it means we didn't get a success result yet.
          // Check if we heard anything to give immediate feedback instead of waiting for timeout.
          if (_lastHeard.isNotEmpty) {
             debugPrint("Speech session ended with input: $_lastHeard");
             _handleSpeechSessionEnded();
          }
        }
      }
    });
    
    // Pre-warm speech engine
    SpeechService().init();
    
    // Start practice sequence
    _startPractice();
  }

  @override
  void didUpdateWidget(SpeakingPracticeView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.word.id != oldWidget.word.id) {
      _resetAndRestart();
    }
  }

  void _resetAndRestart() {
    _cancelAllTimers();
    SpeechService().cancel();
    
    setState(() {
      _state = SpeakingState.idle;
      _lastHeard = '';
      _retryCount = 0;

    });
    
    _pulseController.reset();
    _startPractice();
  }

  void _cancelAllTimers() {
    _skipTimer?.cancel();
    _listenTimeoutTimer?.cancel();
    _successTimer?.cancel();
  }

  @override
  void dispose() {
    _cancelAllTimers();
    _listeningSubscription?.cancel();
    _pulseController.dispose();
    SpeechService().cancel();
    super.dispose();
  }

  /// Main practice flow
  Future<void> _startPractice() async {
    if (!mounted) return;
    
    // Small delay for widget transition
    await Future.delayed(const Duration(milliseconds: 200));
    if (!mounted) return;
    
    // Play standard pronunciation
    setState(() => _state = SpeakingState.playingAudio);
    
    await AudioService().playWord(widget.word);
    
    // Allow audio focus to release
    await Future.delayed(const Duration(milliseconds: 400));
    if (!mounted) return;
    
    // Start listening
    _beginListening();
  }

  void _beginListening() {
    if (!mounted || _state == SpeakingState.success) return;
    
    // Cancel any existing timers before starting new session
    _skipTimer?.cancel();
    _listenTimeoutTimer?.cancel();
    
    setState(() {
      _state = SpeakingState.listening;
      _lastHeard = '';
    });
    
    _pulseController.repeat();
    
    // Start skip button timer (reduced from 5s to 3s)
    _skipTimer = Timer(const Duration(seconds: _skipButtonDelaySeconds), () {
      if (mounted) setState(() {});  // Trigger rebuild to show skip button
    });
    
    // Start listen timeout timer
    _listenTimeoutTimer = Timer(const Duration(seconds: _listenTimeoutSeconds), () {
      _handleListenTimeout();
    });
    
    // Actually start listening
    _startSpeechRecognition();
  }

  Future<void> _startSpeechRecognition() async {
    final success = await SpeechService().startListening(
      onResult: _handleSpeechResult,
      onError: (error) {
        debugPrint('Speech error: $error');
        if (mounted && _state == SpeakingState.listening) {
          _scheduleRetry();
        }
      },
    );
    
    if (!success && mounted && _state == SpeakingState.listening) {
      debugPrint('Failed to start listening, scheduling retry');
      _scheduleRetry();
    }
  }

  void _scheduleRetry() {
    if (_retryCount >= _maxRetries) {
      // Max retries reached - show skip button, set state to failed
      debugPrint('Max retries reached, showing skip prompt');
      _pulseController.stop();
      _pulseController.reset();
      setState(() {
        _state = SpeakingState.failed;
        _lastHeard = ''; // Clear any partial text
      });
      return;
    }
    
    _retryCount++;
    debugPrint('Retry attempt $_retryCount/$_maxRetries');
    
    // Update UI to show retry is happening
    if (mounted) {
      setState(() {
        _lastHeard = ''; // Clear previous heard text
      });
    }
    
    // Delay before retry
    Future.delayed(const Duration(milliseconds: 800), () {
      if (mounted && _state == SpeakingState.listening) {
        _startSpeechRecognition();
      }
    });
  }

  void _handleListenTimeout() {
    if (!mounted || _state != SpeakingState.listening) return;
    
    debugPrint('Listen timeout');
    SpeechService().stopListening();
    
    if (_lastHeard.isEmpty) {
      // No speech detected at all
      if (_retryCount < _maxRetries) {
        _retryCount++;
        debugPrint('Timeout retry attempt $_retryCount/$_maxRetries');
        // Restart listening after a short delay
        Future.delayed(const Duration(milliseconds: 500), () {
          if (mounted && _state == SpeakingState.listening) {
            _startSpeechRecognition();
            // Reset timeout timer
            _listenTimeoutTimer = Timer(const Duration(seconds: _listenTimeoutSeconds), () {
              _handleListenTimeout();
            });
          }
        });
      } else {
        // Max retries - set to failed state and show skip
        debugPrint('Max retries reached after timeout');
        _pulseController.stop();
        _pulseController.reset();
        setState(() {
          _state = SpeakingState.failed;
        });
      }
    } else {
      // Some speech was detected but didn't match - prompt retry
      _showRetryPrompt(_lastHeard);
    }
  }

  void _handleSpeechSessionEnded() {
    _listenTimeoutTimer?.cancel(); // Cancel timeout since session ended naturally
    
    // We already have _lastHeard populated from onResult
    // Since we are still here, it means it wasn't a Success (3 stars) or Good (2 stars)
    // It must be a 0 or 1 star match.
    
    // Trigger retry prompt with error feedback
    _showRetryPrompt(_lastHeard);
  }

  void _handleSpeechResult(String text) {
    if (!mounted || _state != SpeakingState.listening) return;
    
    final recognized = text.toLowerCase().replaceAll(RegExp(r'[^\w\s]'), '').trim();
    if (recognized.isEmpty) return;
    
    setState(() => _lastHeard = recognized);
    
    final target = widget.word.text.toLowerCase().replaceAll(RegExp(r'[^\w\s]'), '').trim();
    
    // Calculate match quality and stars
    final stars = _calculateStars(recognized, target);
    
    // Only auto-pass with 2+ stars
    if (stars >= 2) {
      _handleResult(stars, recognized);
    } else if (stars == 1) {
      // Partial match - prompt to try again
      debugPrint('Partial match only (1 star), prompting retry');
      _listenTimeoutTimer?.cancel(); // Cancel timeout, we have input
      _showRetryPrompt(recognized);
    }
    // If stars == 0, continue listening for more input
  }

  /// Calculate stars based on match quality
  /// Normalize common abbreviations in educational content
  /// Maps abbreviations to their spoken forms for better matching
  String _normalizeAbbreviations(String text) {
    final abbreviations = {
      'sb.': 'somebody',
      'sb': 'somebody',
      'sth.': 'something', 
      'sth': 'something',
      'esp.': 'especially',
      'etc.': 'et cetera',
      'e.g.': 'for example',
      'i.e.': 'that is',
      'vs.': 'versus',
      'adj.': 'adjective',
      'adv.': 'adverb',
      'n.': 'noun',
      'v.': 'verb',
      'prep.': 'preposition',
    };
    
    String result = text.toLowerCase();
    abbreviations.forEach((abbr, full) {
      result = result.replaceAll(abbr.toLowerCase(), full);
    });
    
    // Also remove punctuation for cleaner matching
    result = result.replaceAll(RegExp(r'[^\w\s]'), ' ').replaceAll(RegExp(r'\s+'), ' ').trim();
    
    return result;
  }

  /// Calculate stars based on speech recognition match quality
  int _calculateStars(String recognized, String target) {
    // Normalize both strings for comparison
    String normalizedRecognized = _normalizeAbbreviations(recognized);
    String normalizedTarget = _normalizeAbbreviations(target);
    
    // Check for exact match or contains
    if (normalizedRecognized == normalizedTarget || normalizedRecognized.contains(normalizedTarget)) {
      return 3; // Perfect!
    }
    
    // Check Levenshtein distance for close matches
    int distance = _levenshtein(normalizedRecognized, normalizedTarget);
    
    if (distance <= 1) {
      return 3; // Very close, treat as perfect
    }
    
    if (distance <= 3) {
      return 2; // Good match
    }
    
    // Check Soundex (phonetic match)
    String targetSoundex = PhoneticUtils.soundex(normalizedTarget);
    for (String word in normalizedRecognized.split(' ')) {
      if (PhoneticUtils.soundex(word) == targetSoundex) {
        return 2; // Phonetically similar
      }
    }
    
    // Check if target words appear in recognized
    List<String> targetWords = normalizedTarget.split(' ');
    List<String> recognizedWords = normalizedRecognized.split(' ');
    
    int matchedWords = 0;
    for (String tw in targetWords) {
      if (tw.length < 2) continue; // Skip short words
      if (recognizedWords.any((rw) => rw == tw || _levenshtein(rw, tw) <= 1)) {
        matchedWords++;
      }
    }
    
    // If most words match, it's a good match
    if (targetWords.isNotEmpty && matchedWords >= targetWords.length * 0.7) {
      return 2;
    }
    
    // Check if target word appears in any form
    if (recognizedWords.any((w) => _levenshtein(w, normalizedTarget) <= 2)) {
      return 1; // Partial match - will trigger retry
    }
    
    // If we detected speech but couldn't match at all, return 1 (will trigger retry)
    if (recognized.isNotEmpty) {
      return 1;
    }
    
    return 0; // No match at all
  }

  /// Show retry prompt when speech was detected but not matched well
  void _showRetryPrompt(String recognized) {
    if (!mounted) return;
    
    // Play wrong sound effect
    AudioService().playAsset('wrong.mp3');
    
    // Cancel timers and stop current listening
    _skipTimer?.cancel();
    _listenTimeoutTimer?.cancel();
    SpeechService().stopListening();
    _pulseController.stop();
    
    setState(() {
      _state = SpeakingState.failed;
    });
    
    // Auto-restart after showing feedback
    Future.delayed(const Duration(milliseconds: 1500), () {
      if (mounted && _state == SpeakingState.failed) {
        _retryCount++;
        if (_retryCount < _maxRetries) {
          _beginListening();
        } else {
          // Max retries - show skip
          setState(() {});
        }
      }
    });
  }

  void _handleResult(int stars, String recognized) {
    if (!mounted || _state == SpeakingState.success) return;
    
    _cancelAllTimers();
    SpeechService().stopListening();
    _pulseController.stop();
    _pulseController.reset();
    
    setState(() {
      _state = SpeakingState.success;

      _lastHeard = recognized;
    });
    
    _showSuccessOverlay(stars);
  }



  void _skip() {
    _cancelAllTimers();
    SpeechService().cancel();
    _pulseController.stop();
    _pulseController.reset();
    widget.onCompleted(0); // 0 score for skip
  }

  void _replayStandardAudio() async {
    if (_state != SpeakingState.listening) return;
    
    // Pause listening while playing
    await SpeechService().stopListening();
    _listenTimeoutTimer?.cancel();
    _pulseController.stop();
    
    setState(() => _state = SpeakingState.playingAudio);
    
    await AudioService().playWord(widget.word);
    await Future.delayed(const Duration(milliseconds: 300));
    
    if (mounted && _state == SpeakingState.playingAudio) {
      _beginListening();
    }
  }

  void _showSuccessOverlay(int stars) {
    // Sound effect
    AudioService().playAsset('correct.mp3');
    
    showGeneralDialog(
      context: context,
      barrierDismissible: false,
      barrierLabel: "Success",
      barrierColor: Colors.transparent,
      transitionDuration: Duration.zero,
      pageBuilder: (context, a1, a2) {
        return PracticeSuccessOverlay(
          word: widget.word,
          title: _getStarTitle(stars),
          stars: stars,
        );
      },
    );

    // Play word pronunciation after a short delay
    Future.delayed(const Duration(milliseconds: 600), () {
      if (mounted) {
        AudioService().playWord(widget.word);
      }
    });

    // Auto-advance
    _successTimer = Timer(const Duration(milliseconds: 2500), () {
      if (mounted) {
        Navigator.of(context).pop(); // Close overlay
        widget.onCompleted(stars);
      }
    });
  }

  String _getStarTitle(int stars) {
    switch (stars) {
      case 3: return '太棒了！';
      case 2: return '不错哦！';
      case 1: return '继续加油！';
      default: return '完成！';
    }
  }

  // Levenshtein distance algorithm
  int _levenshtein(String s, String t) {
    if (s == t) return 0;
    if (s.isEmpty) return t.length;
    if (t.isEmpty) return s.length;

    List<int> v0 = List<int>.filled(t.length + 1, 0);
    List<int> v1 = List<int>.filled(t.length + 1, 0);

    for (int i = 0; i < t.length + 1; i++) {
      v0[i] = i;
    }

    for (int i = 0; i < s.length; i++) {
      v1[0] = i + 1;
      for (int j = 0; j < t.length; j++) {
        int cost = (s[i] == t[j]) ? 0 : 1;
        v1[j + 1] = [v1[j] + 1, v0[j + 1] + 1, v0[j] + cost].reduce((min, e) => e < min ? e : min);
      }
      for (int j = 0; j < t.length + 1; j++) {
        v0[j] = v1[j];
      }
    }
    return v1[t.length];
  }

  /// Determine if skip button should be visible
  bool _shouldShowSkipButton() {
    // Show skip after timeout in listening state
    if (_state == SpeakingState.listening && _skipTimer?.isActive == false) {
      return true;
    }
    // Show skip when failed and max retries reached
    if (_state == SpeakingState.failed && _retryCount >= _maxRetries) {
      return true;
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {

    return SizedBox.expand(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isWide = constraints.maxWidth > constraints.maxHeight && constraints.maxWidth > 480;

          if (isWide) {
            return Row(
              children: [
                Expanded(
                  flex: 4,
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _buildTargetWord(),
                        const SizedBox(height: 32),
                        _buildStatusHUD(),
                      ],
                    ),
                  ),
                ),
                Expanded(
                  flex: 5,
                  child: Container(
                    decoration: const BoxDecoration(
                      color: Colors.white54,
                      border: Border(left: BorderSide(color: Colors.black12)),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Spacer(),
                        _buildVoiceWave(),
                        const Spacer(),
                        _buildVoiceControls(),
                        const Spacer(),
                      ],
                    ),
                  ),
                ),
              ],
            );
          }

          // Portrait Layout
          return Column(
            children: [
              Expanded(
                flex: 4,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Spacer(),
                      _buildTargetWord(),
                      const SizedBox(height: 32),
                      _buildStatusHUD(),
                      const Spacer(),
                    ],
                  ),
                ),
              ),
              
              // Bottom Controls Area
              Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(24, 32, 24, 48),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(32),
                    topRight: Radius.circular(32),
                  ),
                  boxShadow: [
                    BoxShadow(color: Colors.black12, blurRadius: 20, offset: Offset(0, -5))
                  ]
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildVoiceWave(),
                    const SizedBox(height: 32),
                    _buildVoiceControls(),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildVoiceWave() {
     // Placeholder for audio visualizer or just some spacing
     return SizedBox(
       height: 60,
       child: Center(
         child: _state == SpeakingState.listening 
           ? Row(
               mainAxisAlignment: MainAxisAlignment.center,
               children: List.generate(5, (index) => 
                 Container(
                   width: 6,
                   height: 20 + 20 * (index % 2 == 0 ? 1.0 : 0.6), // Fake wave
                   margin: const EdgeInsets.symmetric(horizontal: 4),
                   decoration: BoxDecoration(
                     color: AppColors.primary.withValues(alpha: 0.6),
                     borderRadius: BorderRadius.circular(10)
                   ),
                 ).animate(onPlay: (c) => c.repeat(reverse: true))
                  .scaleY(begin: 0.5, end: 1.5, duration: Duration(milliseconds: 300 + index * 100))
               ),
             )
           : const SizedBox.shrink()
       ),
     );
  }

  Widget _buildVoiceControls() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Left: Skip button or Placeholder
          SizedBox(
            width: 80,
            child: _shouldShowSkipButton() 
              ? TextButton(
                  onPressed: _skip,
                  child: Text("跳过", style: TextStyle(color: Colors.grey.shade400)),
                )
              : const SizedBox(),
          ),

          // Center: Mic Button
          _buildVoiceMicButton(),

          // Right: Replay Button
          SizedBox(
            width: 80,
            child: Align(
              alignment: Alignment.centerRight,
              child: AnimatedSpeakerButton(
                onPressed: _replayStandardAudio,
                isPlaying: _state == SpeakingState.playingAudio,
                size: 24,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVoiceMicButton() {
    final isListening = _state == SpeakingState.listening;
    
    return GestureDetector(
      onTap: () {
        if (_state == SpeakingState.idle || _state == SpeakingState.failed) {
          _startPractice();
        } 
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        width: 80, height: 80, // Much smaller
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: isListening ? const Color(0xFFFF5252) : AppColors.primary,
          boxShadow: [
            BoxShadow(
              color: (isListening ? const Color(0xFFFF5252) : AppColors.primary).withValues(alpha: 0.3),
              blurRadius: 20,
              offset: const Offset(0, 8),
            )
          ]
        ),
        child: Icon(
          isListening ? Icons.mic_rounded : Icons.mic_none_rounded,
          color: Colors.white,
          size: 32,
        ),
      ),
    );
  }

  Widget _buildTargetWord() {
    return Column(
      children: [
        Text(
          "READ ALOUD",
          style: GoogleFonts.plusJakartaSans(
            fontSize: 12, fontWeight: FontWeight.w900, 
            color: AppColors.textMediumEmphasis, letterSpacing: 1.0
          ),
        ),
        const SizedBox(height: 16),
        Text(
          widget.word.text,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 48, // Much larger
            fontWeight: FontWeight.w900,
            color: AppColors.primary,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        Text(
          widget.word.phonetic,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 20,
            fontWeight: FontWeight.w500,
            color: AppColors.textMediumEmphasis,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          widget.word.meaning,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: AppColors.textHighEmphasis.withValues(alpha: 0.6),
          ),
        ),
      ],
    );
  }

  Widget _buildStatusHUD() {
    String text;
    Color color;
    IconData? icon;

    switch (_state) {
      case SpeakingState.idle:
      case SpeakingState.playingAudio:
        text = '请听发音...';
        color = AppColors.textMediumEmphasis;
        icon = Icons.volume_up_rounded;
        break;
      case SpeakingState.listening:
        if (_lastHeard.isNotEmpty) {
          text = '听到: "$_lastHeard"';
          color = AppColors.primary;
          icon = Icons.hearing_rounded;
        } else {
          text = '请大声读出来...';
          color = AppColors.secondary;
          icon = Icons.mic_rounded;
        }
        break;
      case SpeakingState.processing:
        text = '正在识别...';
        color = AppColors.primary;
        icon = Icons.sync_rounded;
        break;
      case SpeakingState.success:
        text = '完美!';
        color = Colors.green;
        icon = Icons.check_circle_rounded;
        break;
      case SpeakingState.failed:
        text = '再试一次!';
        color = Colors.orange;
        icon = Icons.refresh_rounded;
        break;
    }

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 300),
      child: Container(
        key: ValueKey(_state),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(30),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(width: 8),
            Text(
              text,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }


}

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/database/models/word.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/services/audio_service.dart';
import '../../../../core/services/speech_service.dart';
import '../../../../core/utils/phonetic_utils.dart';
import '../../../../core/widgets/animated_speaker_button.dart';

import '../../../../core/widgets/bubbly_button.dart';
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
  int _stars = 0;
  
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
        // Visual feedback when mic actually activates
        if (isActive) {
          AudioService().playAsset('mic_start.mp3');
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
    super.didUpdateWidget(oldWidget);;
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
      _stars = 0;
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
      _stars = stars;
      _lastHeard = recognized;
    });
    
    _showSuccessOverlay(stars);
  }

  /// Allow user to manually retry after failed state
  void _retryFromFailed() {
    if (_state == SpeakingState.playingAudio || _state == SpeakingState.success) return;
    
    // Reset retry count for manual retry
    _retryCount = 0;
    _lastHeard = '';
    _beginListening();
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
      pageBuilder: (_, __, ___) {
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

    for (int i = 0; i < t.length + 1; i++) v0[i] = i;

    for (int i = 0; i < s.length; i++) {
      v1[0] = i + 1;
      for (int j = 0; j < t.length; j++) {
        int cost = (s[i] == t[j]) ? 0 : 1;
        v1[j + 1] = [v1[j] + 1, v0[j + 1] + 1, v0[j] + cost].reduce((min, e) => e < min ? e : min);
      }
      for (int j = 0; j < t.length + 1; j++) v0[j] = v1[j];
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
    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                // Word Card
                _buildWordCard(),
                
                const SizedBox(height: 16),
                
                // Example Sentence
                _buildExampleCard(),

                const SizedBox(height: 48),
                
                // Status Text
                _buildStatusText(),
                
                const SizedBox(height: 24),
                
                // Mic Button
                _buildMicButton(),
                
                // Skip Button - show after timeout or when max retries reached
                if (_shouldShowSkipButton()) ...[
                  const SizedBox(height: 32),
                  _buildSkipButton(),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildWordCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.grey.shade100),
        boxShadow: const [
          BoxShadow(color: AppColors.shadowWhite, offset: Offset(0, 4), blurRadius: 0)
        ],
      ),
      child: Column(
        children: [
          const SizedBox(height: 16),
          Text(
            widget.word.text, 
            style: GoogleFonts.plusJakartaSans(
              fontSize: 32, 
              fontWeight: FontWeight.w900, 
              color: AppColors.primary
            ),
          ),
          const SizedBox(height: 8),
          Text(
            widget.word.meaning, 
            style: GoogleFonts.plusJakartaSans(
              fontSize: 20, 
              fontWeight: FontWeight.bold, 
              color: AppColors.textHighEmphasis
            ),
          ),
          const SizedBox(height: 8),
          Text(
            widget.word.phonetic, 
            style: const TextStyle(
              fontSize: 18, 
              color: AppColors.textMediumEmphasis, 
              fontWeight: FontWeight.w500
            ),
          ),
          const SizedBox(height: 24),
          
          // TTS Button with animation
          AnimatedSpeakerButton(
            onPressed: _replayStandardAudio,
            isPlaying: _state == SpeakingState.playingAudio,
            size: 32,
          ),
        ],
      ),
    );
  }

  Widget _buildExampleCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: const Border(left: BorderSide(color: AppColors.primary, width: 4)),
        boxShadow: const [
          BoxShadow(color: AppColors.shadowWhite, offset: Offset(0, 2), blurRadius: 0)
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'EXAMPLE SENTENCE', 
            style: GoogleFonts.plusJakartaSans(
              fontSize: 10, 
              fontWeight: FontWeight.w900, 
              color: AppColors.textMediumEmphasis, 
              letterSpacing: 1.0
            ),
          ),
          const SizedBox(height: 8),
          if (widget.word.examples.isNotEmpty) ...[
            GestureDetector(
              onTap: () => AudioService().playSentence(widget.word.examples.first['en']!),
              child: Text(
                widget.word.examples.first['en']!,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 18, 
                  color: AppColors.textHighEmphasis, 
                  height: 1.5, 
                  fontWeight: FontWeight.w500
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              widget.word.examples.first['cn']!,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 14, 
                color: AppColors.textMediumEmphasis, 
                height: 1.5
              ),
            ),
          ] else ...[
            Text(
              'No example sentence available.',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 18, 
                color: AppColors.textHighEmphasis, 
                height: 1.5, 
                fontWeight: FontWeight.w500
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildStatusText() {
    String text;
    Color color;
    
    switch (_state) {
      case SpeakingState.idle:
      case SpeakingState.playingAudio:
        text = '正在播放...';
        color = AppColors.textMediumEmphasis;
        break;
      case SpeakingState.listening:
        if (_lastHeard.isNotEmpty) {
          text = '听到: $_lastHeard';
          color = AppColors.primary;
        } else if (SpeechService().isListening) {
          text = '请大声朗读';
          color = AppColors.secondary;
        } else {
          text = '准备中...';
          color = AppColors.secondary.withOpacity(0.5);
        }
        break;
      case SpeakingState.processing:
        text = '识别中...';
        color = AppColors.primary;
        break;
      case SpeakingState.success:
        text = _lastHeard.isNotEmpty ? '听到: $_lastHeard' : '';
        color = AppColors.primary;
        break;
      case SpeakingState.failed:
        text = '再试一次！请说: ${widget.word.text}';
        color = Colors.orange;
        break;
    }
    
    return Text(
      text,
      textAlign: TextAlign.center,
      style: GoogleFonts.plusJakartaSans(
        fontSize: 14,
        fontWeight: FontWeight.w900,
        color: color,
        letterSpacing: 1.0,
      ),
    );
  }

  Widget _buildMicButton() {
    final isActive = _state == SpeakingState.listening && SpeechService().isListening;
    final isListening = _state == SpeakingState.listening;
    final isFailed = _state == SpeakingState.failed;
    final canTap = !isListening && _state != SpeakingState.playingAudio && _state != SpeakingState.success;
    
    return GestureDetector(
      onTap: canTap ? _retryFromFailed : null,
      child: SizedBox(
        width: 100,
        height: 100,
        child: Stack(
          alignment: Alignment.center,
          children: [
            // Outer breathing glow when idle (inviting user to tap)
            if (!isListening && !isFailed)
              TweenAnimationBuilder<double>(
                tween: Tween(begin: 0.8, end: 1.0),
                duration: const Duration(milliseconds: 1200),
                curve: Curves.easeInOut,
                builder: (context, value, child) {
                  return Container(
                    width: 100 + (value * 20),
                    height: 100 + (value * 20),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppColors.secondary.withOpacity(0.15 * value),
                    ),
                  );
                },
                onEnd: () {
                  // This creates a continuous breathing effect
                },
              ),
            
            // Ripple Effects when listening
            if (isListening) ...[
              AnimatedBuilder(
                animation: _pulseController,
                builder: (context, child) {
                  return Container(
                    width: 90 + (_pulseController.value * 80),
                    height: 90 + (_pulseController.value * 80),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppColors.secondary.withOpacity(0.3 * (1 - _pulseController.value)),
                      border: Border.all(
                        color: AppColors.secondary.withOpacity(0.4 * (1 - _pulseController.value)),
                        width: 2,
                      ),
                    ),
                  );
                },
              ),
              if (isActive)
                AnimatedBuilder(
                  animation: _pulseController,
                  builder: (context, child) {
                    final double staggeredValue = (_pulseController.value + 0.5) % 1.0;
                    return Container(
                      width: 90 + (staggeredValue * 80),
                      height: 90 + (staggeredValue * 80),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppColors.secondary.withOpacity(0.2 * (1 - staggeredValue)),
                      ),
                    );
                  },
                ),
              // Third ripple for more dynamic effect
              if (isActive)
                AnimatedBuilder(
                  animation: _pulseController,
                  builder: (context, child) {
                    final double staggeredValue = (_pulseController.value + 0.25) % 1.0;
                    return Container(
                      width: 90 + (staggeredValue * 80),
                      height: 90 + (staggeredValue * 80),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: AppColors.secondary.withOpacity(0.3 * (1 - staggeredValue)),
                          width: 1.5,
                        ),
                      ),
                    );
                  },
                ),
            ],
            
            // Main Button with scale animation
            AnimatedScale(
              scale: isListening ? 1.0 : (isFailed ? 1.05 : 0.95),
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeOut,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: isListening ? 100 : 90,
                height: isListening ? 100 : 90,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: isFailed 
                      ? [Colors.orange.shade400, Colors.orange.shade600]
                      : isListening
                        ? [AppColors.secondary, AppColors.secondary.withRed(220)]
                        : [AppColors.secondary.withOpacity(0.9), AppColors.secondary],
                  ),
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 4),
                  boxShadow: [
                    BoxShadow(
                      color: (isFailed ? Colors.orange : AppColors.secondary).withOpacity(isListening ? 0.6 : 0.4),
                      blurRadius: isListening ? 35 : 20,
                      spreadRadius: isListening ? 6 : 0,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 200),
                  child: Icon(
                    isFailed ? Icons.refresh_rounded : (isListening ? Icons.graphic_eq_rounded : Icons.mic_rounded),
                    key: ValueKey(isFailed ? 'refresh' : (isListening ? 'eq' : 'mic')),
                    color: const Color(0xFF101418),
                    size: 42,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _getButtonColor(bool isActive, bool isListening, bool isFailed) {
    if (isFailed) return Colors.orange;
    if (isActive) return AppColors.secondary;
    if (isListening) return Colors.grey;
    return AppColors.secondary;
  }

  Widget _buildSkipButton() {
    return BubblyButton(
      onPressed: _skip,
      color: const Color(0xFFFFF3E0),
      shadowColor: const Color(0xFFFFB74D),
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
      borderRadius: 30,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.fast_forward_rounded, color: Colors.orange.shade800, size: 24),
          const SizedBox(width: 8),
          Text(
            "跳过此词", 
            style: GoogleFonts.plusJakartaSans(
              fontWeight: FontWeight.w800, 
              fontSize: 16, 
              color: Colors.orange.shade800
            ),
          ),
        ],
      ),
    );
  }
}

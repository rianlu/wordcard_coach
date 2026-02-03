import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/database/models/word.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/services/audio_service.dart';
import '../../../../core/services/speech_service.dart';
import '../../../../core/utils/phonetic_utils.dart';
import 'dart:ui';

import '../../../../core/widgets/bubbly_button.dart';
import 'practice_success_overlay.dart';



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
  late AnimationController _controller;
  bool _isListening = false; // Session Active Flag
  bool _isMicActive = false; // Actual Mic Status Flag
  String _lastHeard = '';
  bool _showSuccess = false; 
  bool _showSkip = false;
  
  Timer? _skipTimer;
  Timer? _successTimer;
  StreamSubscription<bool>? _listeningSubscription;
  
  // Simple Levenshtein distance for fuzzy matching
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


  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    );
    // Pre-warm the speech engine (Init only, don't listen yet)
    SpeechService().init();
    
    // Start Practice
    _startPracticeSequence();
    
    // Subscribe to listening state for instant UI feedback & Sound Cue
    _listeningSubscription = SpeechService().listeningState.listen((isPlaying) {
      if (mounted) {
         setState(() => _isMicActive = isPlaying);
         if (isPlaying) {
            // Play "Ping" sound cue when mic actually activates
            AudioService().playAsset('mic_start.mp3');
         }
      }
    });
  }


  @override
  void didUpdateWidget(SpeakingPracticeView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.word != oldWidget.word) {
      _resetState();
      _startPracticeSequence();
    }
  }

  void _resetState() {
     _isListening = false;
     _isMicActive = false;
     _lastHeard = '';
     _showSuccess = false;
     _skipTimer?.cancel();
     _successTimer?.cancel();
     _controller.reset();
     SpeechService().stopListening();
  }

  @override
  void dispose() {
    _listeningSubscription?.cancel();
    _skipTimer?.cancel();
    _successTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _startPracticeSequence() async {
     // Ensure we start clean
     SpeechService().stopListening();
     
     if (mounted) {
       // Play Audio and Wait
       await AudioService().playWord(widget.word);
       
       // Allow audio focus to clear
       if (mounted) await Future.delayed(const Duration(milliseconds: 500));
       
       // Start lazy timer for skip button (e.g. 5 seconds)
       if (mounted) {
         _skipTimer = Timer(const Duration(seconds: 5), () {
           if (mounted && !_showSuccess) {
             setState(() => _showSkip = true);
           }
         });
       }

       // Start listening after audio
       if (mounted) _startListeningSession();
     }
  }

  void _startListeningSession() {
     // If success is showing, don't start
     if (_showSuccess) return;
     
     setState(() {
       _isListening = true; // Set session flag
       _controller.repeat();
     });
     
     // Start Monitor Loop
     _monitorListening(initial: true);
  }
  
  void _monitorListening({bool initial = false}) async {
     // Watchdog Loop: Keeps checking if we should be listening but aren't
     while (mounted && _isListening && !_showSuccess) {
         // Check frequency
         await Future.delayed(const Duration(milliseconds: 500)); // Faster checks
     }
  }
             // Only throttle if NOT initial start
             if (!initial) {
                 debugPrint("Watchdog: Restarting Listening...");
                 await Future.delayed(const Duration(milliseconds: 1000));
             }
             initial = false; // Clear initial flag after first check
             
             if (mounted && _isListening && !_showSuccess) {
                try {
                   await SpeechService().startListening(
                     onResult: (text) {
                       if (!mounted) return;
                       _handleSpeechResult(text);
                     },
                   );
                 } catch (e) {
                   debugPrint("Watchdog: Start Listening Failed: $e");
                   // Wait a bit before retrying to avoid rapid loop
                   await Future.delayed(const Duration(milliseconds: 1000));
                 }
             }
         }
         // Check frequency
         await Future.delayed(const Duration(milliseconds: 500)); // Faster checks
     }
  }

  Future<void> _stopListeningSession() async {
    _isListening = false; // Kill watchdog loop
    await SpeechService().stopListening();
    if (mounted) {
      setState(() {
         _isMicActive = false;
         _controller.stop();
         _controller.reset();
      });
    }
  }

  void _handleSpeechResult(String text) {
      final recognized = text.toLowerCase().replaceAll(RegExp(r'[^\w\s]'), '').trim();
      final target = widget.word.text.toLowerCase().replaceAll(RegExp(r'[^\w\s]'), '').trim();
      
      setState(() => _lastHeard = recognized);
      
      // 1. Exact/Contains Match
      bool exactMatch = recognized.contains(target);
      // 2. Levenshtein Distance (Typos)
      int dist = _levenshtein(recognized, target);
      bool fuzzyMatch = dist <= 2;
      // 3. Phonetic Match (Soundex)
      bool phoneticMatch = false;
      String targetSoundex = PhoneticUtils.soundex(target);
      List<String> heardWords = recognized.split(' ');
      for (String hw in heardWords) {
         if (PhoneticUtils.soundex(hw) == targetSoundex) {
           phoneticMatch = true;
           break;
         }
      }
      if (!phoneticMatch && PhoneticUtils.soundex(recognized) == targetSoundex) {
          phoneticMatch = true; 
      }
      if (exactMatch || fuzzyMatch || phoneticMatch) {
             // Success logic upgrade
             _isListening = false; // Stop loop
             _isMicActive = false;
             SpeechService().stopListening(); 
                          // Show nice success badge
             // Show nice success badge as Dialog
             if (mounted) {
               _showSuccessOverlay();
             }
             
             // Play success sound logic here (optional)
          }
  }
  
  // Re-map toggle to new functions
  void _toggleListening() {
    if (_isListening) {
      _stopListeningSession();
    } else {
      _startListeningSession();
    }
  }

  Future<void> _skip() async {
    await _stopListeningSession();
    widget.onCompleted(0); // Fail/Skip
  }



  @override
  Widget build(BuildContext context) {
    // Determine Status Text
    String statusText = '准备中...'; // Default to Preparing
    Color statusColor = AppColors.textMediumEmphasis;
    
    if (_isListening) {
        if (_isMicActive) {
            statusText = '请大声朗读'; // Only show this when actually ready
            statusColor = AppColors.secondary;
        } else {
            statusText = '准备中...'; // Connecting/Initializing
            statusColor = AppColors.secondary.withOpacity(0.5); 
        }
    } else {
       statusText = '点击麦克风开始';
    }
    
    if (_lastHeard.isNotEmpty) {
        statusText = '听到: $_lastHeard';
        statusColor = AppColors.primary;
    }

    return Stack(
      children: [
        Column(
         children: [
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                // Word Card
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: Colors.grey.shade100),
                    boxShadow: const [
                      BoxShadow(color: AppColors.shadowWhite, offset: Offset(0, 4), blurRadius: 0)
                    ]
                  ),
                  child: Column(
                    children: [
                      const SizedBox(height: 16),
                      Text(widget.word.text, style: GoogleFonts.plusJakartaSans(fontSize: 32, fontWeight: FontWeight.w900, color: AppColors.primary)),
                      const SizedBox(height: 8),
                      Text(widget.word.meaning, style: GoogleFonts.plusJakartaSans(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.textHighEmphasis)),
                      const SizedBox(height: 8),
                      Text(widget.word.phonetic, style: const TextStyle(fontSize: 18, color: AppColors.textMediumEmphasis, fontWeight: FontWeight.w500)),
                      const SizedBox(height: 24),
                      
                      // TTS Button
                      Container(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: AppColors.primary,
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.primary.withOpacity(0.4),
                              blurRadius: 24,
                              offset: const Offset(0, 8),
                            ),
                          ]
                        ),
                        child: IconButton(
                          padding: const EdgeInsets.all(14),
                          onPressed: () async {
                              // Smart Pause: Stop listening loop temporarily
                              bool wasListening = _isListening;
                              if (wasListening) {
                                await SpeechService().stopListening(); // Actually stop engine to prevent echo
                                // Don't set _isListening = false, just stop the engine.
                                // Actually better to flag it.
                                setState(() {
                                   _isListening = false;
                                   _isMicActive = false;
                                   _controller.stop();
                                   _controller.reset();
                                });
                              }
                              
                              await AudioService().playWord(widget.word);
                              
                              // Resume Auto-Listening
                              if (wasListening) {
                                 _startListeningSession();
                              }
                          },
                          icon: const Icon(Icons.volume_up_rounded, color: AppColors.shadowWhite, size: 32),
                        ),
                      ),
                    ],
                  ),
                ),
                
                const SizedBox(height: 16),
                
                // Example Sentence
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                     borderRadius: BorderRadius.circular(12),
                     border: const Border(left: BorderSide(color: AppColors.primary, width: 4)),
                     boxShadow: const [
                        BoxShadow(color: AppColors.shadowWhite, offset: Offset(0, 2), blurRadius: 0)
                     ]
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('EXAMPLE SENTENCE', style: GoogleFonts.plusJakartaSans(fontSize: 10, fontWeight: FontWeight.w900, color: AppColors.textMediumEmphasis, letterSpacing: 1.0)),
                       const SizedBox(height: 8),
                       if (widget.word.examples.isNotEmpty) ...[
                         Text(
                           widget.word.examples.first['en']!,
                           style: GoogleFonts.plusJakartaSans(fontSize: 18, color: AppColors.textHighEmphasis, height: 1.5, fontWeight: FontWeight.w500),
                         ),
                         const SizedBox(height: 8),
                         Text(
                           widget.word.examples.first['cn']!,
                           style: GoogleFonts.plusJakartaSans(fontSize: 14, color: AppColors.textMediumEmphasis, height: 1.5),
                         ),
                       ] else ...[
                         Text(
                           'No example sentence available for "${widget.word.text}".',
                           style: GoogleFonts.plusJakartaSans(fontSize: 18, color: AppColors.textHighEmphasis, height: 1.5, fontWeight: FontWeight.w500),
                         ),
                         const SizedBox(height: 8),
                         Text(
                           '暂无例句',
                           style: GoogleFonts.plusJakartaSans(fontSize: 14, color: AppColors.textMediumEmphasis, height: 1.5),
                         ),
                       ],
                    ],
                  ),
                ),

                const SizedBox(height: 48),
                Text(
                    statusText,
                    textAlign: TextAlign.center,
                    style: GoogleFonts.plusJakartaSans(
                        fontSize: 14, // Slightly larger
                        fontWeight: FontWeight.w900,
                        color: statusColor,
                        letterSpacing: 1.0
                    )
                ),

                const SizedBox(height: 24),
                // Mic Interaction
                GestureDetector(
                  // 长按开始 (Now acts as toggle/restart)
                  onTap: () => _toggleListening(),
                  child: SizedBox(
                    width: 100,
                    height: 100,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        // Ripple Effect (Multi-Ring) - Only if Mic Active
                        if (_isListening) ...[
                          // Ring 1
                          AnimatedBuilder(
                            animation: _controller,
                            builder: (context, child) {
                              return Container(
                                width: 90 + (_controller.value * 70),
                                height: 90 + (_controller.value * 70),
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: AppColors.secondary.withOpacity(0.4 * (1 - _controller.value)),
                                  border: Border.all(
                                    color: AppColors.secondary.withOpacity(0.2 * (1 - _controller.value)),
                                    width: 1,
                                  ),
                                ),
                              );
                            },
                          ),
                          // Ring 2 (Staggered or Scaled) - Only if Mic Active for visual feedback of 'alive'
                          if (_isMicActive)
                          AnimatedBuilder(
                            animation: _controller,
                            builder: (context, child) {
                              final double staggeredValue = (_controller.value + 0.5) % 1.0;
                              return Container(
                                width: 90 + (staggeredValue * 70),
                                height: 90 + (staggeredValue * 70),
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: AppColors.secondary.withOpacity(0.2 * (1 - staggeredValue)),
                                ),
                              );
                            },
                          ),
                        ],
                        // Main Button
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 150),
                          width: _isListening ? 100 : 90,
                          height: _isListening ? 100 : 90,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: _isMicActive ? AppColors.secondary : (_isListening ? Colors.grey : AppColors.secondary), // Grey if preparing? OR just keep secondary.
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 4),
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.secondary.withOpacity(0.4),
                                blurRadius: _isListening ? 30 : 20,
                                spreadRadius: _isListening ? 4 : 0,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Icon(
                              _isListening ? Icons.graphic_eq_rounded : Icons.mic_rounded,
                              color: const Color(0xFF101418),
                              size: 42
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                
                 // Skip Button (Delayed) - Moved here for better visibility
                if (_showSkip && !_showSuccess) ...[
                   const SizedBox(height: 32),
                   BubblyButton(
                     onPressed: _skip,
                     color: const Color(0xFFFFF3E0), // Light Orange
                     shadowColor: const Color(0xFFFFB74D),
                     padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                     borderRadius: 30,
                     child: Row(
                       mainAxisSize: MainAxisSize.min,
                       children: [
                          Icon(Icons.fast_forward_rounded, color: Colors.orange.shade800, size: 24),
                          const SizedBox(width: 8),
                          Text("跳过此词", style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w800, fontSize: 16, color: Colors.orange.shade800)),
                       ],
                     ),
                   ),
                ]
              ],
            ),
          ),
        ),

      ],
    ),
        
      ],
    );
  }

  void _showSuccessOverlay() {
    AudioService().playAsset('correct.mp3');
    showGeneralDialog(
      context: context,
      barrierDismissible: false,
      barrierLabel: "Success",
      barrierColor: Colors.transparent, // Blur handles the background
      transitionDuration: Duration.zero, // Overlay has internal animation
      pageBuilder: (_, __, ___) {
        return PracticeSuccessOverlay(
          word: widget.word,
          title: "正确!",
        );
      },
    );

    // Auto-advance Timer
    _successTimer = Timer(const Duration(milliseconds: 1200), () {
      if (mounted) {
        Navigator.of(context).pop(); // Close overlay
        widget.onCompleted(5); // Advance
      }
    });
  }
}

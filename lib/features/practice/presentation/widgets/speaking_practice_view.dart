import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/database/models/word.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/services/audio_service.dart';
import '../../../../core/services/speech_service.dart';
import '../../../../core/utils/phonetic_utils.dart';
import 'dart:ui';

import '../../../../core/widgets/bubbly_button.dart';



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
  bool _isListening = false;
  String _lastHeard = '';
  bool _showSuccess = false; 
  bool _showSkip = false;
  
  // Timer for skip button
  Future<void>? _skipTimer;
  
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
    // Start Practice
    _startPracticeSequence();
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
     _lastHeard = '';
     _showSuccess = false;
     _showSkip = false;
     _controller.reset();
     SpeechService().stopListening();
     // Reset skip timer logic logic if needed, actually startPractice will handle it
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _startPracticeSequence() async {
     // Ensure we start clean
     SpeechService().stopListening();
     
     if (mounted) {
       // Play Audio and Wait
       await AudioService().playWord(widget.word);
       
       // Start lazy timer for skip button (e.g. 5 seconds)
       if (mounted) {
         Future.delayed(const Duration(seconds: 5), () {
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
     _monitorListening();
  }
  
  void _monitorListening() async {
     // Watchdog Loop: Keeps checking if we should be listening but aren't
     while (mounted && _isListening && !_showSuccess) {
         if (!SpeechService().isListening) {
             debugPrint("Watchdog: Restarting Listening...");
             await SpeechService().startListening(
               onResult: (text) {
                 if (!mounted) return;
                 _handleSpeechResult(text);
               },
             );
         }
         // Check frequency
         await Future.delayed(const Duration(milliseconds: 1000));
     }
  }

  Future<void> _stopListeningSession() async {
    _isListening = false; // Kill watchdog loop
    await SpeechService().stopListening();
    if (mounted) {
      setState(() {
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
             SpeechService().stopListening(); 
                          // Show nice success badge
              if (mounted) {
                setState(() {
                  _showSuccess = true;
                });
              }
             
             // Play success sound logic here (optional)
             
             // Delay to show success message then advance
             Future.delayed(const Duration(milliseconds: 1500), () {
               if (mounted) widget.onCompleted(5); // Perfect
               // We don't verify mounted after onCompleted because this widget might be disposed.
             });
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
                    _isListening ? 'Listening...' : (_lastHeard.isNotEmpty ? 'Heard: $_lastHeard' : 'TAP TO SPEAK'),
                    textAlign: TextAlign.center,
                    style: GoogleFonts.plusJakartaSans(
                        fontSize: 14, // Slightly larger
                        fontWeight: FontWeight.w900,
                        color: _isListening ? AppColors.secondary : (_lastHeard.isNotEmpty ? AppColors.primary : AppColors.textMediumEmphasis),
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
                        // Ripple Effect (Multi-Ring)
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
                          // Ring 2 (Staggered or Scaled)
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
                            color: AppColors.secondary,
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
        
        // Success Overlay (Lightweight)
        if (_showSuccess)
          Positioned(
            top: 100, left: 0, right: 0,
            child: Center(
              child: TweenAnimationBuilder<double>(
                 tween: Tween(begin: 0.0, end: 1.0),
                 duration: const Duration(milliseconds: 300),
                 curve: Curves.elasticOut,
                 builder: (context, value, child) {
                    return Transform.scale(
                      scale: value,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                        decoration: BoxDecoration(
                          color: Colors.green,
                          borderRadius: BorderRadius.circular(30),
                          boxShadow: [BoxShadow(color: Colors.green.withOpacity(0.4), blurRadius: 10, offset: Offset(0, 4))]
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.check_circle, color: Colors.white, size: 28),
                            const SizedBox(width: 8),
                            Text("Perfect!", style: GoogleFonts.plusJakartaSans(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white)),
                          ],
                        ),
                      ),
                    );
                 },
              ),
            ),
          ),
          
      ],
    );
  }
}

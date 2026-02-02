import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/database/models/word.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/services/audio_service.dart';
import '../../../../core/services/speech_service.dart';
import '../../../../core/utils/phonetic_utils.dart';
import 'dart:ui';



class SpeakingPracticeView extends StatefulWidget {
  final Word word;
  final VoidCallback onCompleted;

  const SpeakingPracticeView({
    super.key, 
    required this.word, 
    required this.onCompleted
  });

  @override
  State<SpeakingPracticeView> createState() => _SpeakingPracticeViewState();
}

class _SpeakingPracticeViewState extends State<SpeakingPracticeView> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  bool _isListening = false;
  String _lastHeard = '';
  
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
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _toggleListening() async {
    if (_isListening) {
      await SpeechService().stopListening();
      setState(() => _isListening = false);
      _controller.stop();
      _controller.reset();
    } else {
      bool available = await SpeechService().init();
      if (!available) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Speech recognition not available or permission denied.'), backgroundColor: Colors.red)
          );
        }
        return;
      }

      setState(() {
        _isListening = true;
        _lastHeard = ''; // Reset on new attempt
        _controller.repeat();
      });

      await SpeechService().startListening(
        onResult: (text) {
          if (!mounted) return;
          // Clean strings
          final recognized = text.toLowerCase().replaceAll(RegExp(r'[^\w\s]'), '').trim();
          final target = widget.word.text.toLowerCase().replaceAll(RegExp(r'[^\w\s]'), '').trim();
          
          setState(() {
            _lastHeard = recognized;
          });
          
          print("STT Heard: $recognized vs Target: $target");

          // 1. Exact/Contains Match
          bool exactMatch = recognized.contains(target);
          
          // 2. Levenshtein Distance (Typos)
          int dist = _levenshtein(recognized, target);
          bool fuzzyMatch = dist <= 2;

          // 3. Phonetic Match (Soundex)
          // Compare Soundex of the target word with Soundex of the *last word* heard (since user might say a sentence)
          // Or compare with the whole recognized string if it's short.
          // Let's try splitting recognized text into words and checking if any word matches phonetically.
          bool phoneticMatch = false;
          String targetSoundex = PhoneticUtils.soundex(target);
          List<String> heardWords = recognized.split(' ');
          
          for (String hw in heardWords) {
             if (PhoneticUtils.soundex(hw) == targetSoundex) {
               phoneticMatch = true;
               print("Phonetic Match! $hw (${PhoneticUtils.soundex(hw)}) == $target ($targetSoundex)");
               break;
             }
          }
           // Fallback: entire phrase soundex
           if (!phoneticMatch && PhoneticUtils.soundex(recognized) == targetSoundex) {
              phoneticMatch = true; 
           }


          if (exactMatch || fuzzyMatch || phoneticMatch) {
             // Success
             _toggleListening(); // Stop
             ScaffoldMessenger.of(context).showSnackBar(
               SnackBar(content: Text('Perfect! Heard: "$recognized"'), backgroundColor: Colors.green)
             );
             
             // Play success sound logic here if needed (omitted for now)
             
             // Delay to show success message then advance
             Future.delayed(const Duration(milliseconds: 1000), () {
               if (mounted) widget.onCompleted();
             });
          }
        },
      );
    }
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
                          onPressed: () => AudioService().playWord(widget.word),
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
                  // 长按开始
                  onTapDown: (_) => _toggleListening(),
                  // 松开结束
                  onTapUp: (_) => _toggleListening(),
                  onTapCancel: () => _isListening ? _toggleListening() : null,
                  child: SizedBox(
                    width: 100,
                    height: 100,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        // Ripple Effect
                        if (_isListening)
                          AnimatedBuilder(
                            animation: _controller,
                            builder: (context, child) {
                              return Container(
                                width: 90 + (_controller.value * 70),
                                height: 90 + (_controller.value * 70),
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: AppColors.secondary.withOpacity(0.6 * (1 - _controller.value)),
                                  border: Border.all(
                                    color: AppColors.secondary.withOpacity(0.3 * (1 - _controller.value)),
                                    width: 2,
                                  ),
                                ),
                              );
                            },
                          ),
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
              ],
            ),
          ),
        ),
      ],
    );
  }
}

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/database/models/word.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/services/tts_service.dart';
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

  void _toggleListening() {
    setState(() {
      _isListening = !_isListening;
      if (_isListening) {
        _controller.repeat();
        // Simulate successful speaking after 2 seconds
        Future.delayed(const Duration(seconds: 2), () {
           if (mounted && _isListening) {
             _toggleListening(); // Stop listening UI
             ScaffoldMessenger.of(context).showSnackBar(
               const SnackBar(content: Text('Great job! Correct pronunciation.'), backgroundColor: Colors.green, duration: Duration(milliseconds: 1000),)
             );
             // Trigger completion
             widget.onCompleted();
           }
        });
      } else {
        _controller.stop();
        _controller.reset();
      }
    });
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
                          onPressed: () => TtsService().speak(widget.word.text),
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
                    _isListening ? 'Listening...' : 'TAP TO SPEAK',
                    style: GoogleFonts.plusJakartaSans(
                        fontSize: 12,
                        fontWeight: FontWeight.w900,
                        color: _isListening ? AppColors.secondary : AppColors.textMediumEmphasis,
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

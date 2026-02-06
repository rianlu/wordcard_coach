import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/database/models/word.dart';
import '../../../../core/widgets/bubbly_button.dart';
import '../../../../core/widgets/animated_speaker_button.dart';
import '../../../../core/services/audio_service.dart';

class WordLearningCard extends StatefulWidget {
  final Word word;
  final VoidCallback onNext;

  const WordLearningCard({
    super.key, 
    required this.word, 
    required this.onNext
  });

  @override
  State<WordLearningCard> createState() => _WordLearningCardState();
}

class _WordLearningCardState extends State<WordLearningCard> {
  bool _isPlaying = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _playAudio();
    });
  }

  @override
  void didUpdateWidget(WordLearningCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.word.id != widget.word.id) {
       setState(() {
         _isPlaying = false;
       });
       _playAudio();
    }
  }

  Future<void> _playAudio() async {
    if (_isPlaying) return;

    setState(() {
      _isPlaying = true;
    });

    try {
      await AudioService().playWord(widget.word);
    } finally {
      if (mounted) {
        await Future.delayed(const Duration(milliseconds: 50));
        if (mounted) {
          setState(() {
             _isPlaying = false;
          });
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned.fill(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 120), // Bottom padding for floating button
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                 // 1. Main Word Card
                 Container(
                   padding: const EdgeInsets.all(32),
                   decoration: BoxDecoration(
                     color: Colors.white,
                     borderRadius: BorderRadius.circular(32),
                     boxShadow: const [
                       BoxShadow(color: AppColors.shadowWhite, offset: Offset(0, 8), blurRadius: 16),
                       BoxShadow(color: Colors.black12, offset: Offset(0, 4), blurRadius: 4),
                     ],
                   ),
                   child: Column(
                     children: [
                       // Word
                       Text(
                         widget.word.text, 
                         textAlign: TextAlign.center,
                         style: GoogleFonts.plusJakartaSans(
                           fontSize: 48, 
                           fontWeight: FontWeight.w900, 
                           color: AppColors.primary
                         )
                       ),
                       
                       const SizedBox(height: 16),
                       
                       // Phonetic Chip
                       Container(
                         padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                         decoration: BoxDecoration(
                           color: AppColors.background,
                           borderRadius: BorderRadius.circular(12)
                         ),
                         child: Text(
                           widget.word.displayPhonetic, 
                           style: GoogleFonts.notoSans(
                             fontSize: 18, 
                             fontWeight: FontWeight.w500, 
                             color: AppColors.textMediumEmphasis
                           )
                         ),
                       ),
                       
                       const SizedBox(height: 24),
                       
                       // Audio Button with animation
                       AnimatedSpeakerButton(
                         onPressed: _playAudio,
                         isPlaying: _isPlaying,
                         size: 32,
                       ),


                       const SizedBox(height: 32),
                       const Divider(height: 1, color: Color(0xFFF1F5F9)), // slate-100
                       const SizedBox(height: 24),
                       
                       // Meaning
                       Text(
                         widget.word.meaning, 
                         textAlign: TextAlign.center,
                         style: GoogleFonts.notoSans(
                           fontSize: 24, 
                           fontWeight: FontWeight.bold, 
                           color: AppColors.textHighEmphasis
                         )
                       ),
                     ],
                   ),
                 ),

                 const SizedBox(height: 24),

                 // 2. Example Card
                 Container(
                   padding: const EdgeInsets.all(24),
                   decoration: BoxDecoration(
                     color: Colors.white,
                     borderRadius: BorderRadius.circular(24),
                     border: const Border(left: BorderSide(color: AppColors.secondary, width: 4)),
                     boxShadow: const [
                        BoxShadow(color: AppColors.shadowWhite, offset: Offset(0, 4), blurRadius: 8),
                     ],
                   ),
                   child: Column(
                     crossAxisAlignment: CrossAxisAlignment.start,
                     children: [
                       Row(
                         children: [
                           Icon(Icons.format_quote_rounded, color: AppColors.secondary.withOpacity(0.8), size: 20),
                           const SizedBox(width: 8),
                           Text(
                             "EXAMPLE SENTENCE", 
                             style: GoogleFonts.plusJakartaSans(
                               fontSize: 12, 
                               fontWeight: FontWeight.w900, 
                               color: AppColors.secondary, 
                               letterSpacing: 1.2
                             )
                           ),
                         ],
                       ),
                       const SizedBox(height: 16),
                       if (widget.word.examples.isNotEmpty) ...[
                          GestureDetector(
                            onTap: () => AudioService().playSentence(widget.word.examples.first['en']!),
                            child: Text(
                              widget.word.examples.first['en']!,
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 20, 
                                height: 1.5, 
                                color: AppColors.textHighEmphasis, 
                                fontWeight: FontWeight.w600
                              ),
                            ),
                          ),
                         const SizedBox(height: 12),
                         Text(
                           widget.word.examples.first['cn']!,
                           style: GoogleFonts.notoSans(
                             fontSize: 16, 
                             height: 1.5, 
                             color: AppColors.textMediumEmphasis
                           ),
                         ),
                       ] else ...[
                         Text(
                           "No example sentence available.",
                           style: GoogleFonts.plusJakartaSans(
                             fontSize: 18, height: 1.5, color: AppColors.textHighEmphasis, fontWeight: FontWeight.w500
                           ),
                         ),
                         const SizedBox(height: 8),
                         Text(
                           "暂无例句",
                           style: GoogleFonts.notoSans(
                             fontSize: 16, height: 1.5, color: AppColors.textMediumEmphasis
                           ),
                         ),
                       ],
                     ],
                   ),
                 ),
              ],
            ),
          ),
        ),

        // Floating Next Button
        Positioned(
          left: 24, right: 24, bottom: 32,
          child: BubblyButton(
            onPressed: widget.onNext,
            color: AppColors.primary,
            shadowColor: const Color(0xFF1e3a8a), // Darker blue
            borderRadius: 32,
            padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 32),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  "下一个", // Next
                  style: GoogleFonts.notoSans(
                    color: Colors.white, 
                    fontSize: 18, 
                    fontWeight: FontWeight.w900,
                    letterSpacing: 2.0
                  ),
                ),
                const SizedBox(width: 8),
                const Icon(Icons.arrow_forward_rounded, color: Colors.white, size: 22)
              ],
            ),
          ),
        )
      ],
    );
  }
}

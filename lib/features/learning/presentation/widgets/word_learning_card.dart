import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/database/models/word.dart';
import '../../../../core/widgets/bubbly_button.dart';
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
  bool _isPhonicsVisible = false;
  bool _isPlaying = false;

  @override
  void initState() {
    super.initState();
    // Auto-play on first load
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _playAudio();
    });
  }

  @override
  void didUpdateWidget(WordLearningCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.word.id != widget.word.id) {
       setState(() {
         _isPhonicsVisible = false; // Reset on new word
         _isPlaying = false;
       });
       // Auto-play on word change
       _playAudio();
    }
  }

  // Renamed from _playTts to _playAudio for clarity
  Future<void> _playAudio() async {
    // Determine source of call? 
    // If it's effectively a "restart", we should allow it.
    // But for now, let's just make sure we don't get stuck.
    
    if (_isPlaying) {
      // If user clicks while playing, we could stop and restart, 
      // but simplistic approach for "Stuck" state:
      // If it's stuck for long time, user behavior is to click again.
      // But _isPlaying prevents it.
      // Let's allow clicking if it's been playing "too long"? No, hard to track.
      // Better: Let's rely on the AudioService timeout to unlock us.
      return; 
    }



    
    // Auto-show phonics when playing
    setState(() {
      _isPlaying = true;
      _isPhonicsVisible = true;
    });

    try {
      await AudioService().playWord(widget.word);
    } finally {
      if (mounted) {
        // Use a slight delay to keep the "active" state visible for a moment if play was super fast
        // But for responsiveness, better to reset immediately or after a fix delay
        // Previously we had complex delay logic. Let's simplify.
        // Keeping a very short post-delay (50ms) just to debounce accidental double-clicks
        await Future.delayed(const Duration(milliseconds: 50));

        if (mounted) {
          setState(() {
             _isPlaying = false;
             // _isPhonicsVisible = false; // Keep phonics visible or not? 
             // "Scheme B" says restore.
             // But if user manually toggled it, we shouldn't hide it.
             // We lack "manual toggle" state tracking here.
             // For now, let's just turn off playing state.
             // If we want to hide phonics automatically:
             if (!_isPhonicsVisibleManualOverride()) {
                _isPhonicsVisible = false;
             }
          });
        }
      }
    }
  }

  // Helper to guess if we should hide phonics (not perfect without extra state variable)
  bool _isPhonicsVisibleManualOverride() {
     return false; // For now always auto-hide to keep "Clean" look preferred by user
  }



  void _togglePhonics() {
    setState(() {
      _isPhonicsVisible = !_isPhonicsVisible;
    });
  }

  @override
  Widget build(BuildContext context) {
    // Check if we have syllables data
    final hasSyllables = widget.word.syllables.isNotEmpty;
    // Show phonics if available AND (toggled on OR playing)
    final showPhonics = hasSyllables && (_isPhonicsVisible || _isPlaying);

    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                   // Main Card
                   Container(
                     padding: const EdgeInsets.all(32),
                     decoration: BoxDecoration(
                       color: Colors.white,
                       borderRadius: BorderRadius.circular(24),
                       boxShadow: const [
                         BoxShadow(color: AppColors.shadowWhite, offset: Offset(0, 8), blurRadius: 16),
                         BoxShadow(color: Colors.black12, offset: Offset(0, 4), blurRadius: 4),
                       ],
                     ),
                     child: Column(
                       children: [
                         // Word Display Area
                         Stack(
                           alignment: Alignment.center,
                           clipBehavior: Clip.none,
                           children: [
                             GestureDetector(
                               onTap: hasSyllables ? _togglePhonics : null,
                               child: showPhonics
                                 ? RichText(
                                     textAlign: TextAlign.center,
                                     text: TextSpan(
                                       children: widget.word.syllables.asMap().entries.map((entry) {
                                          final index = entry.key;
                                          final syllable = entry.value;
                                          final color = index % 2 == 0 
                                              ? AppColors.primary 
                                              : const Color(0xFFE91E63);
                                          return TextSpan(
                                            text: syllable,
                                            style: GoogleFonts.plusJakartaSans(
                                              fontSize: 40, 
                                              fontWeight: FontWeight.w900, 
                                              color: color
                                            )
                                          );
                                       }).toList()
                                     ),
                                   )
                                 : Text(
                                     widget.word.text, 
                                     textAlign: TextAlign.center,
                                     style: GoogleFonts.plusJakartaSans(
                                       fontSize: 40, fontWeight: FontWeight.w900, color: AppColors.primary
                                     )
                                   ),
                             ),
                             
                             // Manual Toggle Icon (Visual Hint)
                             if (hasSyllables)
                               Positioned(
                                 right: -40,
                                 top: 0,
                                 bottom: 0,
                                 child: IconButton(
                                   icon: Icon(
                                     showPhonics ? Icons.visibility_off_outlined : Icons.auto_awesome_outlined,
                                     color: AppColors.secondary.withOpacity(0.5),
                                     size: 20,
                                   ),
                                   onPressed: _togglePhonics,
                                   tooltip: "Toggle Phonics",
                                 ),
                               ),
                           ],
                         ),

                         const SizedBox(height: 12),
                         Container(
                           padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                           decoration: BoxDecoration(
                             color: AppColors.background,
                             borderRadius: BorderRadius.circular(12)
                           ),
                           child: Text(
                             widget.word.phonetic, 
                             style: GoogleFonts.notoSans(
                               fontSize: 18, fontWeight: FontWeight.w500, color: AppColors.textMediumEmphasis
                             )
                           ),
                         ),
                         const SizedBox(height: 24),
                         const Divider(height: 1),
                         const SizedBox(height: 24),
                         Text(
                           widget.word.meaning, 
                           textAlign: TextAlign.center,
                           style: GoogleFonts.notoSans(
                             fontSize: 24, fontWeight: FontWeight.bold, color: AppColors.textHighEmphasis
                           )
                         ),
                         const SizedBox(height: 32),
                         // TTS
                         Container(
                            decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: AppColors.primary.withOpacity(0.1),
                            ),
                            child: IconButton(
                              iconSize: 32,
                              padding: const EdgeInsets.all(16),
                              onPressed: _playAudio,

                                icon: const Icon(Icons.volume_up_rounded, color: AppColors.primary),

                            ),
                          ),
                       ],
                     ),
                   ),

                   const SizedBox(height: 24),

                   // Sentence Card
                   Container(
                     padding: const EdgeInsets.all(24),
                     decoration: BoxDecoration(
                       color: Colors.white,
                       borderRadius: BorderRadius.circular(16),
                       border: const Border(left: BorderSide(color: AppColors.secondary, width: 4)),
                       boxShadow: const [
                          BoxShadow(color: AppColors.shadowWhite, offset: Offset(0, 4), blurRadius: 4),
                       ],
                     ),
                     child: Column(
                       crossAxisAlignment: CrossAxisAlignment.start,
                       children: [
                         Row(
                           children: [
                             const Icon(Icons.format_quote_rounded, color: AppColors.secondary),
                             const SizedBox(width: 8),
                             Text(
                               "EXAMPLE", 
                               style: GoogleFonts.plusJakartaSans(
                                 fontSize: 12, fontWeight: FontWeight.w900, color: AppColors.secondary, letterSpacing: 1.2
                               )
                             ),
                           ],
                         ),
                         const SizedBox(height: 12),
                         if (widget.word.examples.isNotEmpty) ...[
                           Text(
                             widget.word.examples.first['en']!,
                             style: GoogleFonts.plusJakartaSans(
                               fontSize: 18, height: 1.5, color: AppColors.textHighEmphasis, fontWeight: FontWeight.w500
                             ),
                           ),
                           const SizedBox(height: 8),
                           Text(
                             widget.word.examples.first['cn']!,
                             style: GoogleFonts.notoSans(
                               fontSize: 16, height: 1.5, color: AppColors.textMediumEmphasis
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
          
          const SizedBox(height: 16),
          BubblyButton(
            onPressed: widget.onNext,
            color: AppColors.primary,
            shadowColor: const Color(0xFF1e3a8a), // Darker blue
            borderRadius: 16,
            padding: const EdgeInsets.symmetric(vertical: 20),
            child: const Center(
              child: Text(
                "下一个 / Next",
                style: TextStyle(
                  color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold
                ),
              ),
            ),
          )
        ],
      ),
    );
  }
}

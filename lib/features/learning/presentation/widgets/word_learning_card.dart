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
    return SizedBox.expand(
      child: LayoutBuilder(
        builder: (context, constraints) {
          // 说明：逻辑说明
          final isWide = constraints.maxWidth > constraints.maxHeight && constraints.maxWidth > 480;

          if (isWide) {
            return Stack(
              children: [
                Row(
                  children: [
                    // 说明：逻辑说明
                    Expanded(
                      flex: 5,
                      child: LayoutBuilder(
                        builder: (context, constraint) {
                          return SingleChildScrollView(
                            padding: const EdgeInsets.all(24),
                            child: ConstrainedBox(
                              constraints: BoxConstraints(minHeight: constraint.maxHeight - 48),
                              child: Center(child: _buildWordInfoCard()),
                            ),
                          );
                        }
                      ),
                    ),
                    // 说明：逻辑说明
                    Expanded(
                      flex: 4,
                      child: Container(
                        decoration: const BoxDecoration(
                          border: Border(left: BorderSide(color: Colors.black12)),
                          color: Colors.white54,
                        ),
                        child: Stack(
                          children: [
                            LayoutBuilder(
                              builder: (context, constraint) {
                                return SingleChildScrollView(
                                  padding: const EdgeInsets.fromLTRB(24, 24, 24, 100),
                                  child: ConstrainedBox(
                                    constraints: BoxConstraints(minHeight: constraint.maxHeight - 124),
                                    child: Center(child: _buildExampleCard()),
                                  ),
                                );
                              }
                            ),
                            Positioned(
                              left: 24, right: 24, bottom: 24,
                              child: _buildNextButton(),
                            )
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            );
          }

          // 竖屏布局
          return Stack(
            children: [
              Positioned.fill(
                child: LayoutBuilder(
                  builder: (context, viewportConstraints) {
                    return SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(24, 64, 24, 120), // 说明：逻辑说明
                      child: ConstrainedBox(
                        constraints: BoxConstraints(
                          minHeight: viewportConstraints.maxHeight - 184, // 说明：逻辑说明
                        ),
                        child: Column(
                          // 说明：逻辑说明
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                             _buildWordInfoCard(),
                             const SizedBox(height: 24),
                             _buildExampleCard(),
                          ],
                        ),
                      ),
                    );
                  }
                ),
              ),
              Positioned(
                left: 24, right: 24, bottom: 32,
                child: _buildNextButton(),
              )
            ],
          );
        },
      ),
    );
  }

  Widget _buildWordInfoCard() {
    return Container(
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
           
           AnimatedSpeakerButton(
             onPressed: _playAudio,
             isPlaying: _isPlaying,
             size: 32,
           ),

           const SizedBox(height: 32),
           const Divider(height: 1, color: Color(0xFFF1F5F9)), 
           const SizedBox(height: 24),
           
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
    );
  }

  Widget _buildExampleCard() {
    return Container(
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
    );
  }

  Widget _buildNextButton() {
    return BubblyButton(
      onPressed: widget.onNext,
      color: AppColors.primary,
      shadowColor: const Color(0xFF1e3a8a), 
      borderRadius: 32,
      padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 32),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            "下一个", 
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
    );
  }
}

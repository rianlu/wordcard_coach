import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/bubbly_button.dart';
import '../../../../core/database/models/word.dart';
import '../../../../core/services/audio_service.dart';
import 'practice_success_overlay.dart';

class WordSelectionView extends StatefulWidget {
  final Word word;
  final List<Word> options;
  final Function(int score) onCompleted;

  const WordSelectionView({
    super.key, 
    required this.word, 
    required this.options, 
    required this.onCompleted
  });

  @override
  State<WordSelectionView> createState() => _WordSelectionViewState();
}

class _WordSelectionViewState extends State<WordSelectionView> {
  String? _selectedOptionId;
  int _wrongAttempts = 0;
  bool _showSuccess = false;

  @override
  void didUpdateWidget(WordSelectionView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.word.id != widget.word.id) {
       setState(() {
         _selectedOptionId = null;
       });
    }
  }

  void _handleOptionSelected(String wordId) {
    if (_selectedOptionId != null) return; // Already selected

    setState(() {
      _selectedOptionId = wordId;
    });

    final isCorrect = wordId == widget.word.id;

    // Simple delay to show result then complete
    Future.delayed(const Duration(milliseconds: 300), () {
      if (mounted) {
          if (isCorrect) {
            // Show Success Overlay Dialog
             if (mounted) {
               _showSuccessOverlay();
             }
          } else {
            // If wrong...
            _showErrorToast();
            setState(() {
              _selectedOptionId = null;
              _wrongAttempts++;
            });
        }
      }
    });
  }

  bool _showError = false;

  void _showErrorToast() {
    if (_showError) return;
    setState(() => _showError = true);
    Future.delayed(const Duration(seconds: 1), () {
      if (mounted) setState(() => _showError = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        _buildMainContent(),

      ],
    );
  }

  void _showSuccessOverlay() {
    // Play Audio
    AudioService().playWord(widget.word);
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
          title: "正确!",
        );
      },
    );

    // Auto-advance Timer
    Future.delayed(const Duration(milliseconds: 1200), () {
      if (mounted) {
        Navigator.of(context).pop(); // Close overlay
        widget.onCompleted(_wrongAttempts == 0 ? 5 : 3);
      }
    });
  }

  Widget _buildMainContent() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
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
          
          const SizedBox(height: 32),
          Align(
            alignment: Alignment.centerLeft, 
            child: Text('SELECT THE CORRECT MEANING', style: GoogleFonts.plusJakartaSans(fontSize: 12, fontWeight: FontWeight.w900, color: AppColors.textMediumEmphasis, letterSpacing: 1.0))
          ),
           const SizedBox(height: 16),
           
           ...widget.options.map((optionWord) => 
             Padding(
               padding: const EdgeInsets.only(bottom: 12),
               child: _buildOption(context, optionWord),
             )
           ),
          
        ],
      ),
    );
  }

  Widget _buildOption(BuildContext context, Word optionWord) {
    // Check if this option is selected
    final isSelected = _selectedOptionId == optionWord.id;
    // Check if this option is correct (only if an option has been selected)
    final isCorrect = optionWord.id == widget.word.id;
    
    // Determine color state
    Color buttonColor = Colors.white;
    Color textColor = AppColors.textHighEmphasis;
    Color borderColor = Colors.transparent;
    Widget? icon;

    if (_selectedOptionId != null) {
      if (optionWord.id == widget.word.id) {
         // Only show correct if user actually picked it
         if (isSelected) {
            buttonColor = const Color(0xFFF0FDF4); // Green 50
            textColor = const Color(0xFF166534); // Green 800
            borderColor = const Color(0xFF86EFAC); // Green 300
            icon = const Icon(Icons.check_circle_rounded, size: 24, color: Color(0xFF166534));
         }
      } else if (isSelected) {
         // This is a wrong selection
         buttonColor = const Color(0xFFFEF2F2); // Red 50
         textColor = const Color(0xFF991B1B); // Red 800
         borderColor = const Color(0xFFFCA5A5); // Red 300
         icon = const Icon(Icons.cancel_rounded, size: 24, color: Color(0xFF991B1B));
      } else {
        // Other wrong options fade out slightly
         textColor = AppColors.textMediumEmphasis.withOpacity(0.5);
      }
    }

    // Display meaning if available, otherwise word text (since meaning is placeholder)
    final displayText = optionWord.meaning;

    return GestureDetector(
      onTap: () => _handleOptionSelected(optionWord.id),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
        decoration: BoxDecoration(
          color: buttonColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: _selectedOptionId != null 
              ? borderColor 
              : Colors.transparent, // No border intially
             width: 2
          ),
          boxShadow: [
             if (_selectedOptionId == null)
               const BoxShadow(color: AppColors.shadowWhite, offset: Offset(0, 4), blurRadius: 12),
          ]
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(child: Text(displayText, style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold, fontSize: 16, color: textColor))),
             if (icon != null)
               Padding(padding: const EdgeInsets.only(left: 12), child: icon)
             else 
               Container(
                 width: 24, height: 24,
                 decoration: BoxDecoration(
                   shape: BoxShape.circle,
                   border: Border.all(color: Colors.grey.shade200, width: 2),
                 ),
               )
          ],
        ),
      ),
    );
  }
}

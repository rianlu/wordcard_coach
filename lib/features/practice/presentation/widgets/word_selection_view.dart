import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/bubbly_button.dart';
import '../../../../core/database/models/word.dart';
import '../../../../core/services/audio_service.dart';

class WordSelectionView extends StatefulWidget {
  final Word word;
  final List<Word> options;
  final Function(bool isCorrect) onCompleted;

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
    Future.delayed(const Duration(seconds: 1), () {
      if (mounted) {
        if (isCorrect) {
          widget.onCompleted();
        } else {
           // If wrong, maybe we want to shake or something, but for now let's just complete or reset
           // Usually in a daily session flow we might want to force retry or mark as incorrect. 
           // For simplicity let's just reset selection to allow retry if wrong, or proceed if correctness logic is handled by parent.
           // But here I'll just allow retry by clearing selection.
           ScaffoldMessenger.of(context).showSnackBar(
               const SnackBar(content: Text('Try again!'), backgroundColor: Colors.red, duration: Duration(milliseconds: 500))
           );
           setState(() {
             _selectedOptionId = null;
           });
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
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
          const Align(
            alignment: Alignment.centerLeft, 
            child: Text('SELECT THE CORRECT MEANING', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: AppColors.textMediumEmphasis, letterSpacing: 1.0))
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
    Color? buttonColor = Colors.white;
    Color? textColor = AppColors.textHighEmphasis;
    Widget? icon;

    if (_selectedOptionId != null) {
      if (optionWord.id == widget.word.id) {
         // Show correct even if user didn't pick it (revealing answer) - logic decision?
         // Let's only show correct green if selected or if we want to reveal. 
         // Logic above: `isCorrect` refers to whether THIS option is the correct answer.
         if (isSelected) {
            buttonColor = Colors.green.shade50;
            textColor = Colors.green.shade800;
            icon = const Icon(Icons.check, size: 20, color: Colors.green);
         } else if (isCorrect) {
             // Maybe highlight correct answer if wrong selected?
             // buttonColor = Colors.green.shade50; 
         }
      } else if (isSelected) {
         // This is a wrong selection
         buttonColor = Colors.red.shade50;
         textColor = Colors.red.shade800;
         icon = const Icon(Icons.close, size: 20, color: Colors.red);
      }
    }

    // Display meaning if available, otherwise word text (since meaning is placeholder)
    final displayText = optionWord.meaning;

    return BubblyButton(
      onPressed: () => _handleOptionSelected(optionWord.id),
      color: buttonColor,
      shadowColor: Colors.grey.shade200,
      shadowHeight: 4,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(child: Text(displayText, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: textColor))),
           Container(
             width: 24, height: 24,
             decoration: BoxDecoration(
               shape: BoxShape.circle,
               border: Border.all(color: Colors.grey.shade300, width: 2),
             ),
             child: icon,
           )
        ],
      )
    );
  }
}

import 'package:flutter/material.dart';
import '../../../../core/services/audio_service.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:math';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/bubbly_button.dart';
import '../../../../core/database/models/word.dart';

import 'practice_success_overlay.dart';

class SpellingPracticeView extends StatefulWidget {
  final Word word;
  final Function(int score) onCompleted;

  const SpellingPracticeView({
    super.key, 
    required this.word, 
    required this.onCompleted
  });

  @override
  State<SpellingPracticeView> createState() => _SpellingPracticeViewState();
}

class _SpellingPracticeViewState extends State<SpellingPracticeView> {

  bool _showSuccess = false; // Add success state
  int _hintsUsed = 0;
  bool _revealFullWord = false; // Show full word when hints exhausted + wrong
  
  // Configuration
  static const int _maxHints = 2; // Maximum hints allowed

  // Game State
  String _targetWord = "";
  List<int> _missingIndices = [];
  List<String> _userInputs = [];
  List<String> _keyboardLetters = [];

  @override
  void initState() {
    super.initState();
    _initializeGame();
  }

  @override
  void didUpdateWidget(SpellingPracticeView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.word.id != widget.word.id) {
       _initializeGame();
    }
  }

  void _initializeGame() {
    _targetWord = widget.word.text;

    _showSuccess = false;
    _hintsUsed = 0;
    _revealFullWord = false;
    
    final random = Random();
    int len = _targetWord.length;
    // Determine how many letters to hide (e.g., 30-50%)
    // Ensure upper bound is at least 1 (for 1-letter words)
    int upperLimit = max(1, len - 1);
    int missingCount = (len * 0.4).ceil().clamp(1, upperLimit);
    
    // Select random unique indices
    Set<int> indices = {};
    // Retry limit to prevent infinite loop for all-space strings (unlikely)
    int attempts = 0;
    while (indices.length < missingCount && attempts < 100) {
      attempts++;
      int randIndex = random.nextInt(len);
      // Don't hide spaces or non-alphanumeric chars if desired, but user specifically asked about spaces.
      if (_targetWord[randIndex].trim().isEmpty) continue;
      
      indices.add(randIndex);
    }
    _missingIndices = indices.toList()..sort();
    _userInputs = List.filled(missingCount, "");

    // Prepare keyboard
    // Include all missing chars
    Set<String> letters = {};
    for (int idx in _missingIndices) {
      letters.add(_targetWord[idx].toUpperCase());
    }
    // Add some random distractors
    const allChars = "ABCDEFGHIJKLMNOPQRSTUVWXYZ";
    while (letters.length < 8) { // Target 8 keys + backspace
       letters.add(allChars[random.nextInt(allChars.length)]);
    }
    _keyboardLetters = letters.toList()..shuffle();
    setState(() {});
  }

  void _handleLetterInput(String char) {
    if (_showSuccess) return; // Block input if already won
    // Find first empty slot
    int emptyIndex = _userInputs.indexOf("");
    if (emptyIndex != -1) {
      setState(() {
        _userInputs[emptyIndex] = char;
      });
      _checkCompletion();
    }
  }

  void _handleBackspace() {
    if (_showSuccess) return;
    // Find last filled slot
    int lastFilledIndex = _userInputs.lastIndexWhere((element) => element.isNotEmpty);
    if (lastFilledIndex != -1) {
      setState(() {
        _userInputs[lastFilledIndex] = "";
      });
    }
  }

  void _useHint() {
    if (_showSuccess || _revealFullWord) return;
    if (_hintsUsed >= _maxHints) return; // Limit reached
    
    // Find empty slots
    List<int> emptyIndices = [];
    for (int i = 0; i < _userInputs.length; i++) {
      if (_userInputs[i].isEmpty) emptyIndices.add(i);
    }

    if (emptyIndices.isNotEmpty) {
      setState(() {
         // Pick random empty slot
         final random = Random();
         int slotIndex = emptyIndices[random.nextInt(emptyIndices.length)];
         
         // Find actual char from target word
         // _missingIndices maps slot index -> word index
         int wordIndex = _missingIndices[slotIndex];
         String char = _targetWord[wordIndex].toUpperCase();
         
         _userInputs[slotIndex] = char;
         _hintsUsed++;
      });
      _checkCompletion();
    }
  }

  bool get _canUseHint => _hintsUsed < _maxHints && !_showSuccess && !_revealFullWord;

  void _checkCompletion() {
    if (!_userInputs.contains("")) {
      // Reconstruct word
      String constructed = "";
      int inputIndex = 0;
      for (int i = 0; i < _targetWord.length; i++) {
        if (_missingIndices.contains(i)) {
          constructed += _userInputs[inputIndex];
          inputIndex++;
        } else {
          constructed += _targetWord[i].toUpperCase();
        }
      }

      if (constructed.toUpperCase() == _targetWord.toUpperCase()) {
         // Correct!
         // 1. Show Success UI Immediately
         setState(() {
           _showSuccess = true;
         });

         // 2. Play Audio Concurrently
         AudioService().playWord(widget.word);
         
         // 3. Show Success Overlay
         if (mounted) {
            _showSuccessOverlay();
         }
      } else {
        // Wrong
         AudioService().playAsset('wrong.mp3');
         
         // Check if hints are exhausted
         if (_hintsUsed >= _maxHints) {
           // Hints exhausted + wrong answer -> reveal full word
           setState(() {
             _revealFullWord = true;
             // Fill in all missing letters
             for (int i = 0; i < _missingIndices.length; i++) {
               int wordIndex = _missingIndices[i];
               _userInputs[i] = _targetWord[wordIndex].toUpperCase();
             }
           });
           
           // Play word pronunciation
           AudioService().playWord(widget.word);
           
           // Auto-advance after showing full word
           Future.delayed(const Duration(milliseconds: 2000), () {
             if (mounted) {
               widget.onCompleted(0); // 0 score for revealed word
             }
           });
         } else {
           // Still have hints, let user retry
           Future.delayed(const Duration(milliseconds: 500), () {
              if (mounted) {
                 _showErrorToast();
                 setState(() {
                   _userInputs = List.filled(_userInputs.length, "");
                 });
              }
           });
         }
      }
    }
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
    return SizedBox.expand(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isWide = constraints.maxWidth > constraints.maxHeight && constraints.maxWidth > 480;

          if (isWide) {
            return Row(
              children: [
                Expanded(
                  flex: 4,
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _buildMeaningHeader(),
                        const Spacer(),
                        _buildPuzzleArea(),
                        const Spacer(),
                        _buildSentenceHint(),
                      ],
                    ),
                  ),
                ),
                Expanded(
                  flex: 5,
                  child: Container(
                    decoration: const BoxDecoration(
                      color: Colors.white54,
                      border: Border(left: BorderSide(color: Colors.black12)),
                    ),
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      children: [
                        const Spacer(),
                        _buildHintButton(),
                        const SizedBox(height: 24),
                        _buildKeyboardArea(),
                        const Spacer(),
                      ],
                    ),
                  ),
                ),
              ],
            );
          }

          // Portrait Layout
          return Column(
            children: [
              // Top Section: Puzzle & Meaning
              Expanded(
                flex: 4,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Column(
                    children: [
                      const Spacer(),
                      _buildMeaningHeader(),
                      const SizedBox(height: 24),
                      _buildPuzzleArea(),
                      const SizedBox(height: 24),
                      _buildSentenceHint(),
                      const Spacer(),
                    ],
                  ),
                ),
              ),
              
              // Bottom Section: Interaction
              Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(32),
                    topRight: Radius.circular(32),
                  ),
                  boxShadow: [
                    BoxShadow(color: Colors.black12, blurRadius: 20, offset: Offset(0, -5))
                  ]
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildHintButton(),
                    const SizedBox(height: 16),
                    _buildKeyboardArea(),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildMeaningHeader() {
    return Column(
      children: [
        Text(
          "SPELL THE WORD",
          style: GoogleFonts.plusJakartaSans(
            fontSize: 12, fontWeight: FontWeight.w900, 
            color: AppColors.textMediumEmphasis, letterSpacing: 1.0
          ),
        ),
        const SizedBox(height: 8),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Text(
            widget.word.meaning,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 24, 
              fontWeight: FontWeight.w900, 
              color: AppColors.primary
            ),
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
  
  Widget _buildPuzzleArea() {
    // Dynamic sizing based on word length
    // If word is long (>8 chars), reduce box size.
    double boxSize = _targetWord.length > 8 ? 32 : 44;
    double fontSize = _targetWord.length > 8 ? 18 : 24;
    double spacing = _targetWord.length > 8 ? 6 : 8;

    return Wrap(
      alignment: WrapAlignment.center,
      spacing: spacing,
      runSpacing: spacing,
      children: List.generate(_targetWord.length, (index) {
         bool isMissing = _missingIndices.contains(index);
         // ... (rest of logic remains the same, just use dynamic sizes)
         String char = _targetWord[index];
         
         String displayChar = char;
         Color bgColor = Colors.grey.shade100;
         Color borderColor = Colors.transparent;
         Color textColor = AppColors.textHighEmphasis;

         if (isMissing) {
           int slotIndex = _missingIndices.indexOf(index);
           if (_userInputs[slotIndex].isNotEmpty) {
             // Filled
             displayChar = _userInputs[slotIndex];
             bgColor = AppColors.primary.withValues(alpha: 0.1);
             borderColor = AppColors.primary;
             textColor = AppColors.primary;
           } else {
             // Empty slot
             displayChar = "";
             bgColor = Colors.white;
             borderColor = Colors.grey.shade300;
           }
         } else {
            // Fixed letter
            bgColor = Colors.grey.shade200;
            textColor = Colors.grey.shade500;
         }

         return Container(
           width: boxSize, height: boxSize * 1.2, // Maintain aspect ratio
           alignment: Alignment.center,
           decoration: BoxDecoration(
             color: bgColor,
             borderRadius: BorderRadius.circular(8),
             border: Border.all(color: borderColor, width: 2),
           ),
           child: Text(
             displayChar.toUpperCase(),
             style: GoogleFonts.plusJakartaSans(
               fontSize: fontSize,
               fontWeight: FontWeight.w900,
               color: textColor,
             ),
           ),
         );
      }),
    );
  }

  Widget _buildSentenceHint() {
    if (widget.word.examples.isEmpty) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
         widget.word.examples.first['en']!.replaceAll(RegExp(widget.word.text, caseSensitive: false), "____"),
         style: GoogleFonts.plusJakartaSans(fontSize: 14, color: AppColors.textMediumEmphasis, fontStyle: FontStyle.italic),
         textAlign: TextAlign.center,
      ),
    );
  }

  Widget _buildKeyboardArea() {
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      alignment: WrapAlignment.center,
      children: [
        ..._keyboardLetters.map((char) => _buildLetterButton(char)),
        _buildBackspaceButton(),
      ],
    );
  }

  Widget _buildHintButton() {
    return Padding(
       padding: const EdgeInsets.only(bottom: 16),
       child: Visibility(
         visible: _userInputs.contains("") && !_revealFullWord,
         maintainSize: true,
         maintainAnimation: true,
         maintainState: true,
         child: TextButton.icon(
           onPressed: _canUseHint ? _useHint : null,
           icon: Icon(
             Icons.lightbulb_outline, 
             color: _canUseHint ? Colors.orange : Colors.grey,
           ),
           label: Text(
             "提示 ($_hintsUsed/$_maxHints)", 
             style: TextStyle(
               color: _canUseHint ? Colors.orange : Colors.grey, 
               fontWeight: FontWeight.bold,
             ),
           ),
         ),
       ),
     );
  }







  void _showSuccessOverlay() {
    AudioService().playAsset('correct.mp3');
    showGeneralDialog(
      context: context,
      barrierDismissible: false,
      barrierLabel: "Success",
      barrierColor: Colors.transparent, 
      transitionDuration: Duration.zero,
      pageBuilder: (context, a1, a2) {
        return PracticeSuccessOverlay(
          word: widget.word,
          title: "正确!",
        );
      },
    );

    // Delay then Advance
    Future.delayed(const Duration(milliseconds: 1200), () {
      if (mounted) {
         Navigator.of(context).pop(); // Close overlay
         int score = _hintsUsed > 0 ? 3 : 5;
         widget.onCompleted(score);
      }
    });
  }

  Widget _buildLetterButton(String char) {
    return SizedBox(
      width: 56, height: 56,
      child: BubblyButton(
        onPressed: () => _handleLetterInput(char),
        color: Colors.white,
        shadowColor: Colors.grey.shade300, 
        padding: EdgeInsets.zero,
        borderRadius: 16,
        child: Center(
          child: Text(char, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.textHighEmphasis)),
        ),
      ),
    );
  }

  Widget _buildBackspaceButton() {
     return SizedBox(
      width: 56, height: 56,
      child: BubblyButton(
        onPressed: _handleBackspace,
        color: const Color(0xFFFEE2E2), // Red 100
        shadowColor: const Color(0xFFFECaca),
        padding: EdgeInsets.zero,
        borderRadius: 16,
        child: const Center(
          child: Icon(Icons.backspace, color: Color(0xFFEF4444), size: 20),
        ),
      ),
    );
  }
}

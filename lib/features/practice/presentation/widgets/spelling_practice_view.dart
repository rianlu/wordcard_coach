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
  bool _isHintVisible = false;
  bool _showSuccess = false; // Add success state
  int _hintsUsed = 0; 

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
    _isHintVisible = false;
    _showSuccess = false;
    _hintsUsed = 0;
    
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
    if (_showSuccess) return;
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
         
         // 3. Delay then Advance
         Future.delayed(const Duration(milliseconds: 1500), () {
            if (mounted) {
               int score = _hintsUsed > 0 ? 3 : 5;
               widget.onCompleted(score);
            }
         });
      } else {
        // Wrong
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
                        Text(widget.word.meaning, style: GoogleFonts.plusJakartaSans(fontSize: 32, fontWeight: FontWeight.w900, color: AppColors.primary)),
                        const SizedBox(height: 16),
                        Text(widget.word.phonetic, style: const TextStyle(fontSize: 18, color: AppColors.textMediumEmphasis, fontWeight: FontWeight.w500)),
                      ],
                    ),
                  ),
                  
                  const SizedBox(height: 16),
  
                  // Hint Button (Always takes space)
                  Padding(
                     padding: const EdgeInsets.only(bottom: 16),
                     child: Visibility(
                       visible: _userInputs.contains(""),
                       maintainSize: true,
                       maintainAnimation: true,
                       maintainState: true,
                       child: TextButton.icon(
                         onPressed: _useHint,
                         icon: const Icon(Icons.lightbulb_outline, color: Colors.orange),
                         label: const Text("提示 (Hint)", style: TextStyle(color: Colors.orange, fontWeight: FontWeight.bold)),
                       ),
                     ),
                   ),
                  
                  // Example Sentence with styling
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
                         if (widget.word.examples.isNotEmpty)
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                 Expanded(
                                   child: Text(
                                      widget.word.examples.first['en']!.replaceAll(RegExp(widget.word.text, caseSensitive: false), "____"),
                                      style: GoogleFonts.plusJakartaSans(fontSize: 18, color: AppColors.textHighEmphasis, height: 1.5, fontWeight: FontWeight.w500),
                                   ),
                                 ),
                              ],
                            )
                         else
                            Text(
                               'No example sentence available.',
                               style: GoogleFonts.plusJakartaSans(fontSize: 18, color: AppColors.textHighEmphasis, height: 1.5, fontWeight: FontWeight.w500),
                            ),
                      ],
                    ),
                  ),
  
                  const SizedBox(height: 32),
  
                  // Missing Letter Puzzle
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
                    decoration: BoxDecoration(
                       color: Colors.white,
                       borderRadius: BorderRadius.circular(20),
                       border: Border.all(color: Colors.grey.shade200),
                    ),
                    child: Wrap(
                      alignment: WrapAlignment.center,
                      spacing: 8,
                      runSpacing: 16,
                      children: List.generate(_targetWord.length, (index) {
                         bool isMissing = _missingIndices.contains(index);
                         String char = _targetWord[index];
                         
                         String displayChar = char;
                         Color textColor = AppColors.textHighEmphasis;
                         bool showUnderscore = false;
  
                         if (isMissing) {
                           int slotIndex = _missingIndices.indexOf(index);
                           if (_userInputs[slotIndex].isNotEmpty) {
                             displayChar = _userInputs[slotIndex];
                             textColor = AppColors.primary; 
                           } else {
                             displayChar = "";
                             showUnderscore = true;
                           }
                         }
  
                         return Column(
                           children: [
                             Text(
                               displayChar.toUpperCase(), 
                               style: TextStyle(
                                 fontSize: 28, 
                                 fontWeight: FontWeight.w900, 
                                 color: textColor
                               )
                             ),
                             if (showUnderscore || isMissing)
                               Container(
                                 width: 24, 
                                 height: 4, 
                                 margin: const EdgeInsets.only(top: 4),
                                 color: showUnderscore ? Colors.grey.shade300 : Colors.transparent
                               ),
                           ],
                         );
                      }),
                    ),
                  ),
                  
                  const SizedBox(height: 24),
                  
                  Text('TAP LETTERS TO FILL', style: GoogleFonts.plusJakartaSans(fontSize: 12, fontWeight: FontWeight.w900, color: Colors.grey.shade400, letterSpacing: 1.0)),
                  const SizedBox(height: 16),
                  
                  // Letter Buttons
                  Wrap(
                    spacing: 16,
                    runSpacing: 16,
                    alignment: WrapAlignment.center,
                    children: [
                      ..._keyboardLetters.map((char) => _buildLetterButton(char)),
                      _buildBackspaceButton(),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
      
      if (_showSuccess)
        PracticeSuccessOverlay(
          word: widget.word,
          title: "太棒了!",
          subtitle: "拼写正确!",
        ),
      ],
    );
  }

  Widget _buildLetterButton(String char) {
    return SizedBox(
      width: 64, height: 64,
      child: BubblyButton(
        onPressed: () => _handleLetterInput(char),
        color: AppColors.secondary,
        shadowColor: const Color(0xFFd4aa00), 
        padding: EdgeInsets.zero,
        borderRadius: 32,
        child: Center(
          child: Text(char, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: AppColors.textHighEmphasis)),
        ),
      ),
    );
  }

  Widget _buildBackspaceButton() {
     return SizedBox(
      width: 64, height: 64,
      child: BubblyButton(
        onPressed: _handleBackspace,
        color: const Color(0xFFe2e8f0),
        shadowColor: const Color(0xFFcbd5e1),
        padding: EdgeInsets.zero,
        borderRadius: 32,
        child: const Center(
          child: Icon(Icons.backspace, color: AppColors.textMediumEmphasis),
        ),
      ),
    );
  }
}

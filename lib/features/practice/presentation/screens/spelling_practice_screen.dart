import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:ui';
import 'dart:math';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/bubbly_button.dart';
import '../../../../core/database/daos/word_dao.dart';
import '../../../../core/database/models/word.dart';

class SpellingPracticeScreen extends StatefulWidget {
  const SpellingPracticeScreen({super.key});

  @override
  State<SpellingPracticeScreen> createState() => _SpellingPracticeScreenState();
}

class _SpellingPracticeScreenState extends State<SpellingPracticeScreen> {
  final WordDao _wordDao = WordDao();
  Word? _currentWord;
  bool _isLoading = true;
  bool _isHintVisible = false;

  // Game State
  String _targetWord = "";
  List<int> _missingIndices = [];
  List<String> _userInputs = [];
  List<String> _keyboardLetters = [];

  @override
  void initState() {
    super.initState();
    _loadNewWord();
  }

  Future<void> _loadNewWord() async {
    setState(() {
      _isLoading = true;
      _isHintVisible = false;
      _userInputs = [];
      _missingIndices = [];
      _keyboardLetters = [];
    });

    try {
      final words = await _wordDao.getNewWords(1);
      if (words.isNotEmpty) {
        _currentWord = words.first;
        _targetWord = _currentWord!.text;
        _initializeGame();
      }
    } catch (e) {
      debugPrint('Error loading word: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _initializeGame() {
    if (_targetWord.isEmpty) return;

    final random = Random();
    int len = _targetWord.length;
    // Determine how many letters to hide (e.g., 30-50%)
    int missingCount = (len * 0.4).ceil().clamp(1, len - 1);
    
    // Select random unique indices
    Set<int> indices = {};
    while (indices.length < missingCount) {
      indices.add(random.nextInt(len));
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
  }

  void _handleLetterInput(String char) {
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
    // Find last filled slot
    int lastFilledIndex = _userInputs.lastIndexWhere((element) => element.isNotEmpty);
    if (lastFilledIndex != -1) {
      setState(() {
        _userInputs[lastFilledIndex] = "";
      });
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
         Future.delayed(const Duration(milliseconds: 500), () {
            if (mounted) {
               ScaffoldMessenger.of(context).showSnackBar(
                 const SnackBar(content: Text('Correct!'), backgroundColor: Colors.green)
               );
               _loadNewWord();
            }
         });
      } else {
        // Wrong
         Future.delayed(const Duration(milliseconds: 500), () {
            if (mounted) {
               ScaffoldMessenger.of(context).showSnackBar(
                 const SnackBar(content: Text('Try again!'), backgroundColor: Colors.red)
               );
               // Clear inputs? Or let user backspace
               setState(() {
                 _userInputs = List.filled(_userInputs.length, "");
               });
            }
         });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: AppColors.background,
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (_currentWord == null) {
      return Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          leading: IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context)),
        ),
        body: const Center(child: Text('No words available')),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.close),
           onPressed: () => Navigator.pop(context),
        ),
        title: Text(_currentWord!.unit, style: const TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 16),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: AppColors.secondary.withOpacity(0.2),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppColors.secondary.withOpacity(0.3)),
            ),
            child: const Row(
              children: [
                Icon(Icons.stars_rounded, color: AppColors.secondary, size: 20),
                SizedBox(width: 4),
                Text('120 XP', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
              ],
            ),
          )
        ],
      ),
      body: Column(
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
                        Text(_currentWord!.meaning, style: GoogleFonts.plusJakartaSans(fontSize: 32, fontWeight: FontWeight.w900, color: AppColors.primary)),
                        const SizedBox(height: 16),
                        Text(_currentWord!.phonetic, style: const TextStyle(fontSize: 18, color: AppColors.textMediumEmphasis, fontWeight: FontWeight.w500)),
                      ],
                    ),
                  ),
                  
                  const SizedBox(height: 16),
                  
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
                         // Use placeholder for now as per plan
                         Text(
                             'No example sentence available.',
                             style: GoogleFonts.plusJakartaSans(fontSize: 18, color: AppColors.textHighEmphasis, height: 1.5, fontWeight: FontWeight.w500),
                         ),
                        
                         // Hint functionality disabled or simplified for now
                         if (_isHintVisible)
                           Padding(
                             padding: const EdgeInsets.only(top: 8.0),
                             child: Text("Word: $_targetWord", style: TextStyle(color: Colors.grey.shade400)),
                           ),
                         
                         const SizedBox(height: 8),
                         GestureDetector(
                           onTap: () => setState(() => _isHintVisible = !_isHintVisible),
                           child: Text(
                             _isHintVisible ? "Hide Hint" : "Show Hint",
                             style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold),
                           ),
                         )
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
                         
                         // Determine content to show
                         String displayChar = char;
                         Color textColor = AppColors.textHighEmphasis;
                         bool showUnderscore = false;

                         if (isMissing) {
                           int slotIndex = _missingIndices.indexOf(index);
                           if (_userInputs[slotIndex].isNotEmpty) {
                             displayChar = _userInputs[slotIndex];
                             textColor = AppColors.primary; // User input color
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
          
          // Bottom Progress
          Container(
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 40),
            decoration: const BoxDecoration(
               color: Colors.white,
               boxShadow: [BoxShadow(color: Colors.black12, offset: Offset(0, -4), blurRadius: 16)]
            ),
            child: Column(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: const LinearProgressIndicator(
                    value: 0.66, 
                    color: AppColors.primary,
                    backgroundColor: Color(0xFFe2e8f0),
                    minHeight: 12,
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('TOTAL PROGRESS', style: GoogleFonts.plusJakartaSans(fontSize: 10, fontWeight: FontWeight.w900, color: AppColors.textMediumEmphasis, letterSpacing: 1.0)),
                    Text('8 / 12 WORDS', style: GoogleFonts.plusJakartaSans(fontSize: 10, fontWeight: FontWeight.w900, color: AppColors.textMediumEmphasis, letterSpacing: 1.0)),
                  ],
                )
              ],
            ),
          )
        ],
      ),
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

import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/bubbly_button.dart';
import 'dart:ui';

class SpellingPracticeScreen extends StatefulWidget {
  const SpellingPracticeScreen({super.key});

  @override
  State<SpellingPracticeScreen> createState() => _SpellingPracticeScreenState();
}

class _SpellingPracticeScreenState extends State<SpellingPracticeScreen> {
  // Mock State
  final String _targetWord = "Enthusiastic";
  final List<int> _missingIndices = [1, 4, 8]; // E_T_US_ASTIC
  final List<String> _userInputs = ["", "", ""]; // Correspond to missing slots
  int _currentSlotIndex = 0; // Which slot we are filling next
  bool _isHintVisible = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.close),
           onPressed: () => Navigator.pop(context),
        ),
        title: const Text('Lesson 12', style: TextStyle(fontWeight: FontWeight.bold)),
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
                        const Text('热情的', style: TextStyle(fontSize: 32, fontWeight: FontWeight.w900, color: AppColors.primary)),
                        const SizedBox(height: 16),
                        const Text('/ɪnˌθuːziˈæstɪk/', style: TextStyle(fontSize: 18, color: AppColors.textMediumEmphasis, fontWeight: FontWeight.w500)),
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
                        Text('EXAMPLE SENTENCE', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: AppColors.textMediumEmphasis, letterSpacing: 1.0)),
                         const SizedBox(height: 8),
                         RichText(
                           text: TextSpan(
                             style: const TextStyle(fontSize: 18, color: AppColors.textHighEmphasis, height: 1.5, fontWeight: FontWeight.w500),
                             children: [
                               const TextSpan(text: '"The crowd gave an '),
                               // TextSpan(text: 'enthusiastic', style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold)),
                               WidgetSpan(alignment: PlaceholderAlignment.middle,
                                 child: GestureDetector(
                                   onTap: () => setState(() => _isHintVisible = !_isHintVisible),
                                   child: ClipRRect( // 裁剪模糊边缘，防止溢出
                                     borderRadius: BorderRadius.circular(4),
                                     child: ImageFiltered(
                                       imageFilter: _isHintVisible
                                           ? ColorFilter.mode(Colors.transparent, BlendMode.multiply) // 不显示时无滤镜
                                           : ImageFilter.blur(sigmaX: 3, sigmaY: 3), // 高斯模糊强度
                                       child: Container(
                                         padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                         decoration: BoxDecoration(
                                           // 模糊时给一个淡淡的底色，增加“磨砂”感
                                           color: _isHintVisible ? Colors.transparent : Colors.grey.shade200.withOpacity(0.5),
                                           borderRadius: BorderRadius.circular(4),
                                         ),
                                         child: Text(
                                           'enthusiastic',
                                           style: TextStyle(
                                             fontSize: 18,
                                             // 模糊时颜色稍微深一点，效果更好
                                             color: _isHintVisible ? AppColors.primary : AppColors.primary,
                                             fontWeight: FontWeight.bold,
                                           ),
                                         ),
                                       ),
                                     ),
                                   ),
                                 ),
                               ),
                               const TextSpan(text: ' cheer for the team!"'),
                             ]
                           ),
                         ),
                        RichText(
                          text: const TextSpan(
                              style: TextStyle(fontSize: 16, color: AppColors.textMediumEmphasis, height: 1.5, fontWeight: FontWeight.w500),
                              children: [
                                TextSpan(text: '"人群为球队发出了 '),
                                TextSpan(text: '热烈的', style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold)),
                                TextSpan(text: '欢呼声！"'),
                              ]
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
                    ), // Using existing container style, maybe could match HTML border-dashed style?
                    // HTML uses: border border-dashed border-slate-300
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
                               displayChar, 
                               style: TextStyle(
                                 fontSize: 28, 
                                 fontWeight: FontWeight.w900, 
                                 color: textColor
                               )
                             ),
                             if (showUnderscore || isMissing) // Always show line for missing slots even if filled? No, logic above.
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
                  
                  Text('TAP LETTERS TO FILL', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: Colors.grey.shade400, letterSpacing: 1.0)),
                  const SizedBox(height: 16),
                  
                  // Letter Buttons
                  Wrap(
                    spacing: 16,
                    runSpacing: 16,
                    children: [
                      _buildLetterButton('N'),
                      _buildLetterButton('U'),
                      _buildLetterButton('I'),
                      _buildLetterButton('R'),
                      _buildLetterButton('E'),
                      _buildLetterButton('F'),
                      _buildLetterButton('S'),
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
                    value: 0.66, // 8/12
                    color: AppColors.primary,
                    backgroundColor: Color(0xFFe2e8f0),
                    minHeight: 12,
                  ),
                ),
                const SizedBox(height: 12),
                const Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('TOTAL PROGRESS', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: AppColors.textMediumEmphasis, letterSpacing: 1.0)),
                    Text('8 / 12 WORDS', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: AppColors.textMediumEmphasis, letterSpacing: 1.0)),
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
        onPressed: () {
          // Logic to fill
        },
        color: AppColors.secondary,
        shadowColor: const Color(0xFFd4aa00), // Darker yellow
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
        onPressed: () {},
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

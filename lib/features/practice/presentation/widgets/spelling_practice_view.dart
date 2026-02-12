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
  final bool isReviewMode;

  const SpellingPracticeView({
    super.key, 
    required this.word, 
    required this.onCompleted,
    this.isReviewMode = false,
  });

  @override
  State<SpellingPracticeView> createState() => _SpellingPracticeViewState();
}

class _SpellingPracticeViewState extends State<SpellingPracticeView> {

  bool _showSuccess = false; // 加入成功状态
  int _hintsUsed = 0;
  bool _revealFullWord = false; // 提示用尽且错误时显示完整单词
  int? _hintHighlightSlot; // 最近一次提示填充的槽位，用于短暂高亮
  
  // 提示次数随题目难度自适应：最多 3 次，避免过度提示
  int get _maxHints => _missingIndices.length.clamp(1, 3);

  // 游戏状态
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
    _hintHighlightSlot = null;
    
    final random = Random();
    int len = _targetWord.length;
    // 计算隐藏字母数量
    // 保证至少隐藏 1 个字母
    int upperLimit = max(1, len - 1);
    int missingCount = (len * 0.4).ceil().clamp(1, min(upperLimit, 7));
    
    // 随机选择唯一索引
    Set<int> indices = {};
    // 重试次数限制
    int attempts = 0;
    while (indices.length < missingCount && attempts < 100) {
      attempts++;
      int randIndex = random.nextInt(len);
      // 不隐藏空格或特殊字符
      if (_targetWord[randIndex].trim().isEmpty) continue;
      
      indices.add(randIndex);
    }
    _missingIndices = indices.toList()..sort();
    _userInputs = List.filled(missingCount, "");

    // 准备键盘
    // 包含所有缺失字母
    Set<String> letters = {};
    for (int idx in _missingIndices) {
      letters.add(_targetWord[idx].toLowerCase());
    }
    // 加入随机干扰字母
    const allChars = "abcdefghijklmnopqrstuvwxyz";
    while (letters.length < 7) { // 固定 7 个字母键
       letters.add(allChars[random.nextInt(allChars.length)]);
    }
    _keyboardLetters = letters.toList()..shuffle();
    setState(() {});
  }

  void _handleLetterInput(String char) {
    if (_showSuccess) return; // 已完成时禁止输入
    // 找到第一个空位
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
    // 找到最后一个已填位置
    int lastFilledIndex = _userInputs.lastIndexWhere((element) => element.isNotEmpty);
    if (lastFilledIndex != -1) {
      setState(() {
        _userInputs[lastFilledIndex] = "";
      });
    }
  }

  void _useHint() {
    if (_showSuccess || _revealFullWord) return;
    if (_hintsUsed >= _maxHints) return; // 达到提示上限
    
    // 从前往后补全，符合低年级拼写回忆习惯
    final int slotIndex = _userInputs.indexOf("");
    if (slotIndex != -1) {
      setState(() {
         // 从目标单词取出实际字母
         // 缺失索引映射：输入槽位 -> 单词索引
         int wordIndex = _missingIndices[slotIndex];
         String char = _targetWord[wordIndex].toLowerCase();
         
         _userInputs[slotIndex] = char;
         _hintsUsed++;
         _hintHighlightSlot = slotIndex;
      });
      Future.delayed(const Duration(milliseconds: 700), () {
        if (!mounted) return;
        if (_hintHighlightSlot == slotIndex) {
          setState(() => _hintHighlightSlot = null);
        }
      });
      _checkCompletion();
    }
  }

  bool get _canUseHint => _hintsUsed < _maxHints && !_showSuccess && !_revealFullWord;

  void _checkCompletion() {
    if (!_userInputs.contains("")) {
      // 重建单词
      String constructed = "";
      int inputIndex = 0;
      for (int i = 0; i < _targetWord.length; i++) {
        if (_missingIndices.contains(i)) {
          constructed += _userInputs[inputIndex];
          inputIndex++;
        } else {
          constructed += _targetWord[i];
        }
      }

      if (constructed.toLowerCase() == _targetWord.toLowerCase()) {
         // 正确
         // 1. 立即显示成功状态
         setState(() {
           _showSuccess = true;
         });

         // 2. 播放音频 同时
         AudioService().playWord(widget.word);
         
         // 3. 显示成功提示层
         if (mounted) {
            _showSuccessOverlay();
         }
      } else {
        // 错误
         AudioService().playAsset('wrong.mp3');
         
         // 检查是否用尽提示
         if (_hintsUsed >= _maxHints) {
           // 提示用尽时展示完整单词
           setState(() {
             _revealFullWord = true;
             // 填充所有缺失字母
             for (int i = 0; i < _missingIndices.length; i++) {
               int wordIndex = _missingIndices[i];
               _userInputs[i] = _targetWord[wordIndex].toLowerCase();
             }
           });
           
           // 播放单词读音
           AudioService().playWord(widget.word);
           
           // 展示完整单词后自动进入下一题
           Future.delayed(const Duration(milliseconds: 2000), () {
             if (mounted) {
               widget.onCompleted(0); // 显示答案时记 0 分
             }
           });
         } else {
           // 还有提示次数，允许重试
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

          // 竖屏布局
          return Column(
            children: [
              // 上部：拼图与释义
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
              
              // 下部：交互区
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
    // 根据单词长度动态调整大小
    // 单词较长时缩小尺寸
    double boxSize = _targetWord.length > 8 ? 32 : 44;
    double fontSize = _targetWord.length > 8 ? 18 : 24;
    double spacing = _targetWord.length > 8 ? 6 : 8;

    return Wrap(
      alignment: WrapAlignment.center,
      spacing: spacing,
      runSpacing: spacing,
      children: List.generate(_targetWord.length, (index) {
         bool isMissing = _missingIndices.contains(index);
         // 其余逻辑保持不变，仅调整尺寸
         String char = _targetWord[index];
         
         String displayChar = char;
         Color bgColor = Colors.grey.shade100;
         Color borderColor = Colors.transparent;
         Color textColor = AppColors.textHighEmphasis;

         if (isMissing) {
           int slotIndex = _missingIndices.indexOf(index);
           final isHintHighlighted = _hintHighlightSlot == slotIndex;
           if (_userInputs[slotIndex].isNotEmpty) {
             // 已填
             displayChar = _userInputs[slotIndex];
             bgColor = isHintHighlighted
                 ? const Color(0xFFFFF4CC)
                 : AppColors.primary.withValues(alpha: 0.1);
             borderColor = isHintHighlighted ? const Color(0xFFF59E0B) : AppColors.primary;
             textColor = isHintHighlighted ? const Color(0xFFB45309) : AppColors.primary;
           } else {
             // 空位
             displayChar = "";
             bgColor = Colors.white;
             borderColor = isHintHighlighted ? const Color(0xFFF59E0B) : Colors.grey.shade300;
           }
         } else {
            // 固定字母
            bgColor = Colors.grey.shade200;
            textColor = Colors.grey.shade500;
         }

         return AnimatedContainer(
           duration: const Duration(milliseconds: 180),
           curve: Curves.easeOut,
           width: boxSize, height: boxSize * 1.2, // 保持宽高比
           alignment: Alignment.center,
           decoration: BoxDecoration(
             color: bgColor,
             borderRadius: BorderRadius.circular(8),
             border: Border.all(color: borderColor, width: 2),
           ),
           child: Text(
             displayChar,
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
    final row1 = _keyboardLetters.take(4).toList();
    final row2 = _keyboardLetters.skip(4).take(3).toList();

    return LayoutBuilder(
      builder: (context, constraints) {
        const spacing = 10.0;
        final buttonSize = ((constraints.maxWidth - spacing * 3) / 4).clamp(44.0, 64.0);
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                for (int i = 0; i < row1.length; i++) ...[
                  _buildLetterButton(row1[i], size: buttonSize),
                  if (i != row1.length - 1) const SizedBox(width: spacing),
                ],
              ],
            ),
            const SizedBox(height: spacing),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                for (int i = 0; i < row2.length; i++) ...[
                  _buildLetterButton(row2[i], size: buttonSize),
                  const SizedBox(width: spacing),
                ],
                _buildBackspaceButton(size: buttonSize),
              ],
            ),
          ],
        );
      },
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
          variant: widget.isReviewMode ? PracticeSuccessVariant.review : PracticeSuccessVariant.learning,
        );
      },
    );

    // 延迟后进入下一题
    Future.delayed(const Duration(milliseconds: 1200), () {
      if (mounted) {
         Navigator.of(context).pop(); // 关闭提示层
         int score = _hintsUsed > 0 ? 3 : 5;
         widget.onCompleted(score);
      }
    });
  }

  Widget _buildLetterButton(String char, {double size = 56}) {
    return SizedBox(
      width: size, height: size,
      child: BubblyButton(
        onPressed: () => _handleLetterInput(char),
        color: Colors.white,
        shadowColor: Colors.grey.shade300, 
        padding: EdgeInsets.zero,
        borderRadius: 16,
        child: Center(
          child: Text(char, style: TextStyle(fontSize: size * 0.36, fontWeight: FontWeight.bold, color: AppColors.textHighEmphasis)),
        ),
      ),
    );
  }

  Widget _buildBackspaceButton({double size = 56}) {
     return SizedBox(
      width: size, height: size,
      child: BubblyButton(
        onPressed: _handleBackspace,
        color: const Color(0xFFFEE2E2), // 红色 100
        shadowColor: const Color(0xFFFECaca),
        padding: EdgeInsets.zero,
        borderRadius: 16,
        child: Center(
          child: Icon(Icons.backspace, color: const Color(0xFFEF4444), size: size * 0.36),
        ),
      ),
    );
  }
}

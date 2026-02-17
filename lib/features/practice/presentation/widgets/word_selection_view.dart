import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/theme/app_colors.dart';

import '../../../../core/widgets/animated_speaker_button.dart';
import '../../../../core/database/models/word.dart';
import '../../../../core/services/audio_service.dart';
import 'practice_success_overlay.dart';

class WordSelectionView extends StatefulWidget {
  final Word word;
  final List<Word> options;
  final Function(int score) onCompleted;
  final bool isReviewMode;

  const WordSelectionView({
    super.key, 
    required this.word, 
    required this.options, 
    required this.onCompleted,
    this.isReviewMode = false,
  });

  @override
  State<WordSelectionView> createState() => _WordSelectionViewState();
}

class _WordSelectionViewState extends State<WordSelectionView> {
  String? _selectedOptionId;
  String? _pressingOptionId;
  int _wrongAttempts = 0;

  bool _isPlaying = false;

  @override
  void didUpdateWidget(WordSelectionView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.word.id != widget.word.id) {
       setState(() {
         _selectedOptionId = null;
         _wrongAttempts = 0;

         _isPlaying = false;
       });
    }
  }

  Future<void> _playAudio() async {
    if (_isPlaying) return;
    setState(() => _isPlaying = true);
    try {
      await AudioService().playWord(widget.word);
    } finally {
      if (mounted) {
        await Future.delayed(const Duration(milliseconds: 50));
        if (mounted) setState(() => _isPlaying = false);
      }
    }
  }

  void _handleOptionSelected(String wordId) {
    if (_selectedOptionId != null) return; // 已选择则忽略

    setState(() {
      _selectedOptionId = wordId;
      _pressingOptionId = null;
    });

    final isCorrect = wordId == widget.word.id;

    // 稍作延迟以展示结果
    Future.delayed(const Duration(milliseconds: 300), () {
      if (mounted) {
          if (isCorrect) {
            // 展示成功提示层
             if (mounted) {
               _showSuccessOverlay();
             }
          } else {
            // 错误时播放提示并重置
            AudioService().playAsset('wrong.mp3');
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
    // 播放音频
    AudioService().playWord(widget.word);
    AudioService().playAsset('correct.mp3');

    showGeneralDialog(
      context: context,
      barrierDismissible: false,
      barrierLabel: "Success",
      barrierColor: Colors.transparent, 
      transitionDuration: Duration.zero,
      pageBuilder: (context, animation, secondaryAnimation) {
        return PracticeSuccessOverlay(
          word: widget.word,
          title: "正确!",
          variant: widget.isReviewMode ? PracticeSuccessVariant.review : PracticeSuccessVariant.learning,
        );
      },
    );

    // 自动进入下一题
    Future.delayed(const Duration(milliseconds: 1200), () {
      if (mounted) {
        Navigator.of(context).pop(); // 关闭提示层
        widget.onCompleted(_wrongAttempts == 0 ? 5 : 3);
      }
    });
  }

  Widget _buildMainContent() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth > constraints.maxHeight && constraints.maxWidth > 480;
        final isTall = constraints.maxHeight > 600;
        final isPhone = constraints.biggest.shortestSide < 600;
        final isPortrait = constraints.maxHeight >= constraints.maxWidth;
        final useSingleColumn = isPhone && isPortrait;

        if (isWide) {
          return Row(
            children: [
              Expanded(
                flex: 4,
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Center(child: _buildWordCard(compactTop: false)),
                ),
              ),
              Expanded(
                flex: 5,
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: _buildOptionsGrid(),
                ),
              ),
            ],
          );
        }

        if (!isTall) {
           // 逻辑处理
           return SingleChildScrollView(
             padding: const EdgeInsets.all(24),
             child: Column(
               children: [
                 _buildWordCard(compactTop: useSingleColumn),
                 const SizedBox(height: 24),
                 // 逻辑处理
                 // 逻辑处理
                 _buildOptionsGrid(shrinkWrap: true, scrollable: false),
               ],
             ),
           );
        }

        // 标准 竖屏布局
        return Column(
          children: [
            Expanded(
              flex: useSingleColumn ? 4 : 4,
              child: Padding(
                padding: EdgeInsets.fromLTRB(24, useSingleColumn ? 24 : 24, 24, useSingleColumn ? 12 : 24),
                child: Center(
                  child: SingleChildScrollView(
                    child: _buildWordCard(compactTop: useSingleColumn)
                  )
                ),
              ),
            ),
            Expanded(
              flex: useSingleColumn ? 6 : 5,
              child: Padding(
                padding: EdgeInsets.fromLTRB(24, 0, 24, useSingleColumn ? 16 : 24),
                child: _buildOptionsGrid(),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildOptionsGrid({bool shrinkWrap = false, bool scrollable = true}) {
    final screen = MediaQuery.of(context).size;
    final isPortrait = screen.height >= screen.width;
    final isPhone = screen.shortestSide < 600;
    final useSingleColumn = isPhone && isPortrait;
    final titleFontSize = useSingleColumn ? 16.0 : 12.0;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: Text(
            '选择正确释义',
            style: GoogleFonts.plusJakartaSans(
              fontSize: titleFontSize,
              fontWeight: FontWeight.w900,
              color: AppColors.textMediumEmphasis,
              letterSpacing: 0.8,
            ),
          ),
        ),
        SizedBox(height: useSingleColumn ? 10 : 16),
        shrinkWrap 
        ? GridView.builder(
            padding: EdgeInsets.zero,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: useSingleColumn ? 1 : 2,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: useSingleColumn ? 3.6 : 1.3,
            ),
            itemCount: widget.options.length,
            itemBuilder: (context, index) {
              return _buildOptionTile(context, widget.options[index], compactSingleColumn: useSingleColumn);
            },
          )
        : Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                // 逻辑处理
                final gap = (constraints.maxWidth * 0.04).clamp(12.0, 20.0);
                return GridView.builder(
                  padding: EdgeInsets.zero,
                  physics: const BouncingScrollPhysics(), 
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: useSingleColumn ? 1 : 2,
                    crossAxisSpacing: gap,
                    mainAxisSpacing: gap,
                    childAspectRatio: useSingleColumn ? 3.6 : 1.3, 
                  ),
                  itemCount: widget.options.length,
                  itemBuilder: (context, index) {
                    return _buildOptionTile(context, widget.options[index], compactSingleColumn: useSingleColumn);
                  },
                );
              },
            ),
          ),
      ],
    );
  }

  Widget _buildWordCard({bool compactTop = false}) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isLearningMode = !widget.isReviewMode;
        final isCompact = constraints.maxWidth < 360;
        final wordFontSize = isCompact
            ? (isLearningMode ? 30.0 : 27.0)
            : (isLearningMode ? (compactTop ? 40.0 : 36.0) : (compactTop ? 35.0 : 32.0));
        final phoneticFontSize = isCompact
            ? (isLearningMode ? 17.0 : 15.0)
            : (isLearningMode ? (compactTop ? 22.0 : 19.0) : (compactTop ? 20.0 : 18.0));

        return Container(
          width: double.infinity,
          padding: EdgeInsets.all(compactTop ? 20 : (isLearningMode ? 24 : 20)),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: Colors.grey.shade100),
            boxShadow: const [
              BoxShadow(color: AppColors.shadowWhite, offset: Offset(0, 4), blurRadius: 0)
            ],
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      widget.word.text,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: wordFontSize,
                        fontWeight: FontWeight.w900,
                        color: AppColors.primary,
                        height: 1.1,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      widget.word.phonetic,
                      style: TextStyle(
                        fontSize: phoneticFontSize,
                        color: AppColors.textMediumEmphasis,
                        fontWeight: FontWeight.w500,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              SizedBox(width: compactTop ? 8 : 12),
              AnimatedSpeakerButton(
                onPressed: _playAudio,
                isPlaying: _isPlaying,
                size: compactTop ? 34 : (isLearningMode ? 34 : 32),
                variant: widget.isReviewMode ? SpeakerButtonVariant.review : SpeakerButtonVariant.learning,
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildOptionTile(BuildContext context, Word optionWord, {bool compactSingleColumn = false}) {
    final isLearningMode = !widget.isReviewMode;
    final isSelected = _selectedOptionId == optionWord.id;
    final isPressed = _pressingOptionId == optionWord.id && _selectedOptionId == null;


    // 弹跳风格配色
    Color bgColor = Colors.white;
    Color borderColor = Colors.transparent;
    Color shadowColor = AppColors.shadowWhite;
    double yOffset = 4;
    Color textColor = AppColors.textHighEmphasis;

    if (_selectedOptionId != null) {
      final isCorrect = optionWord.id == widget.word.id;
      final isSelectedAndCorrect = isCorrect && _selectedOptionId == widget.word.id;

      if (isSelectedAndCorrect) {
         // 正确且被选中：复习模式使用黄系，学习模式使用绿系
         if (widget.isReviewMode) {
           bgColor = const Color(0xFFFFE082);
           borderColor = const Color(0xFFFFC107);
           shadowColor = const Color(0xFFD4AA00);
           textColor = const Color(0xFF664400);
         } else {
           bgColor = AppColors.primary;
           borderColor = const Color(0xFF1A5DBD);
           shadowColor = AppColors.shadowBlue;
           textColor = Colors.white;
         }
      } else if (isSelected) {
         // 错误
         bgColor = const Color(0xFFF87171); // 红色 400
         borderColor = const Color(0xFFEF4444); // 红色 500
         shadowColor = const Color(0xFFB91C1C); // 红色 700
         textColor = Colors.white;
      } else {
         // 其他选项
         bgColor = Colors.grey.shade100;
         textColor = Colors.grey.shade400;
         yOffset = 0; // 按下效果
         shadowColor = Colors.transparent;
      }
    } else {
      // 正常状态
      // 逻辑处理
      bgColor = Colors.white;
      borderColor = Colors.grey.shade200;
      shadowColor = Colors.grey.shade300;
    }

    return GestureDetector(
      onTapDown: (_) {
        if (_selectedOptionId != null) return;
        setState(() => _pressingOptionId = optionWord.id);
      },
      onTapUp: (_) {
        if (_pressingOptionId == optionWord.id) {
          setState(() => _pressingOptionId = null);
        }
      },
      onTapCancel: () {
        if (_pressingOptionId == optionWord.id) {
          setState(() => _pressingOptionId = null);
        }
      },
      onTap: () => _handleOptionSelected(optionWord.id),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        curve: Curves.easeOut,
        transform: Matrix4.translationValues(0, isPressed ? 3 : 0, 0),
        padding: EdgeInsets.symmetric(
          horizontal: compactSingleColumn ? 14 : (isLearningMode ? 18 : 16),
          vertical: compactSingleColumn ? 6 : (isLearningMode ? 18 : 16),
        ),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: borderColor, width: 2),
          boxShadow: [
             BoxShadow(
               color: shadowColor,
               offset: Offset(0, isPressed ? 1 : yOffset),
               blurRadius: 0, // 实体阴影效果
             )
          ]
        ),
        child: Center(
          child: Text(
            optionWord.meaning,
            style: GoogleFonts.plusJakartaSans(
              fontWeight: FontWeight.w800,
              fontSize: compactSingleColumn ? 19 : (isLearningMode ? 17 : 16),
              color: textColor,
              height: compactSingleColumn ? 1.15 : 1.2,
            ),
            textAlign: TextAlign.center,
            maxLines: compactSingleColumn ? 1 : 3,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ),
    );
  }
}

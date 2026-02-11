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
      pageBuilder: (_, __, ___) {
        return PracticeSuccessOverlay(
          word: widget.word,
          title: "正确!",
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

        if (isWide) {
          return Row(
            children: [
              Expanded(
                flex: 4,
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Center(child: _buildWordCard()),
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
                 _buildWordCard(),
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
              flex: 4,
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Center(
                  child: SingleChildScrollView(
                    child: _buildWordCard()
                  )
                ),
              ),
            ),
            Expanded(
              flex: 5,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                child: _buildOptionsGrid(),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildOptionsGrid({bool shrinkWrap = false, bool scrollable = true}) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: Text(
            '选择正确释义',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 12,
              fontWeight: FontWeight.w900,
              color: AppColors.textMediumEmphasis,
              letterSpacing: 1.0,
            ),
          ),
        ),
        const SizedBox(height: 16),
        shrinkWrap 
        ? GridView.builder(
            padding: EdgeInsets.zero,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 1.3,
            ),
            itemCount: widget.options.length,
            itemBuilder: (context, index) {
              return _buildOptionTile(context, widget.options[index]);
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
                    crossAxisCount: 2,
                    crossAxisSpacing: gap,
                    mainAxisSpacing: gap,
                    childAspectRatio: 1.3, 
                  ),
                  itemCount: widget.options.length,
                  itemBuilder: (context, index) {
                    return _buildOptionTile(context, widget.options[index]);
                  },
                );
              },
            ),
          ),
      ],
    );
  }

  Widget _buildWordCard() {
    return Container(
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

          // 带动画的发音按钮
          AnimatedSpeakerButton(
            onPressed: _playAudio,
            isPlaying: _isPlaying,
            size: 32,
          ),
        ],
      ),
    );
  }

  Widget _buildOptionTile(BuildContext context, Word optionWord) {
    final isSelected = _selectedOptionId == optionWord.id;


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
         // 正确且被选中
         bgColor = const Color(0xFF4ADE80); // 绿色 400
         borderColor = const Color(0xFF22C55E); // 绿色 500（边框/阴影）
         shadowColor = const Color(0xFF15803D); // 绿色 700
         textColor = Colors.white;
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
      onTap: () => _handleOptionSelected(optionWord.id),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        curve: Curves.easeOut,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: borderColor, width: 2),
          boxShadow: [
             BoxShadow(
               color: shadowColor,
               offset: Offset(0, yOffset),
               blurRadius: 0, // 实体阴影效果
             )
          ]
        ),
        child: Center(
          child: Text(
            optionWord.meaning,
            style: GoogleFonts.plusJakartaSans(
              fontWeight: FontWeight.w800,
              fontSize: 16,
              color: textColor,
              height: 1.2,
            ),
            textAlign: TextAlign.center,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ),
    );
  }
}

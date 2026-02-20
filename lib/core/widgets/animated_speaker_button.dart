import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

enum SpeakerButtonVariant { neutral, learning, review }

/// 逻辑处理
/// 逻辑处理
class AnimatedSpeakerButton extends StatefulWidget {
  final VoidCallback onPressed;
  final bool isPlaying;
  final double size;
  final SpeakerButtonVariant variant;
  final Color? primaryColor;
  final Color? playingColor;

  const AnimatedSpeakerButton({
    super.key,
    required this.onPressed,
    this.isPlaying = false,
    this.size = 32,
    this.variant = SpeakerButtonVariant.neutral,
    this.primaryColor,
    this.playingColor,
  });

  @override
  State<AnimatedSpeakerButton> createState() => _AnimatedSpeakerButtonState();
}

class _AnimatedSpeakerButtonState extends State<AnimatedSpeakerButton>
    with SingleTickerProviderStateMixin {
  static const double _glowIdleAlpha = 0.22;
  static const double _glowActiveAlpha = 0.36;
  static const double _glowIdleBlur = 14;
  static const double _glowActiveBlur = 22;
  static const double _glowIdleYOffset = 4;
  static const double _glowActiveYOffset = 8;

  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.08).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void didUpdateWidget(AnimatedSpeakerButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isPlaying && !oldWidget.isPlaying) {
      _pulseController.repeat(reverse: true);
    } else if (!widget.isPlaying && oldWidget.isPlaying) {
      _pulseController.stop();
      _pulseController.reset();
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final (defaultPrimary, defaultPlaying) = _resolveVariantColors(
      widget.variant,
    );
    final primary = widget.primaryColor ?? defaultPrimary;
    final playing = widget.playingColor ?? defaultPlaying;
    final currentColor = widget.isPlaying ? playing : primary;
    final iconColor = _resolveIconColor(widget.variant, widget.isPlaying);
    final glowAlpha = widget.isPlaying ? _glowActiveAlpha : _glowIdleAlpha;
    final glowBlur = widget.isPlaying ? _glowActiveBlur : _glowIdleBlur;
    final glowYOffset = widget.isPlaying
        ? _glowActiveYOffset
        : _glowIdleYOffset;

    return GestureDetector(
      onTap: widget.onPressed,
      child: AnimatedBuilder(
        animation: _pulseAnimation,
        builder: (context, child) {
          return Transform.scale(
            scale: widget.isPlaying ? _pulseAnimation.value : 1.0,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: EdgeInsets.all(widget.size * 0.5),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: currentColor,
                boxShadow: [
                  BoxShadow(
                    color: currentColor.withValues(alpha: glowAlpha),
                    blurRadius: glowBlur,
                    offset: Offset(0, glowYOffset),
                  ),
                ],
              ),
              child: Icon(
                widget.isPlaying
                    ? Icons.graphic_eq_rounded
                    : Icons.volume_up_rounded,
                color: iconColor,
                size: widget.size,
              ),
            ),
          );
        },
      ),
    );
  }

  (Color, Color) _resolveVariantColors(SpeakerButtonVariant variant) {
    switch (variant) {
      case SpeakerButtonVariant.learning:
        // 学习模式：播放中更亮，不做压暗
        return (AppColors.primary, const Color(0xFF4A97FF));
      case SpeakerButtonVariant.review:
        // 复习模式：播放中更亮的黄
        return (AppColors.secondary, const Color(0xFFFFD84D));
      case SpeakerButtonVariant.neutral:
        return (const Color(0xFFE2E8F0), const Color(0xFF94A3B8));
    }
  }

  Color _resolveIconColor(SpeakerButtonVariant variant, bool isPlaying) {
    switch (variant) {
      case SpeakerButtonVariant.learning:
        return Colors.white;
      case SpeakerButtonVariant.review:
        return Colors.white;
      case SpeakerButtonVariant.neutral:
        return isPlaying ? Colors.white : const Color(0xFF475569);
    }
  }
}

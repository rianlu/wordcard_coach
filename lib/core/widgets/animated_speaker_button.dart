import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

/// An animated speaker button that shows playing state with color change
/// and pulsing animation.
class AnimatedSpeakerButton extends StatefulWidget {
  final VoidCallback onPressed;
  final bool isPlaying;
  final double size;
  final Color primaryColor;
  final Color playingColor;

  const AnimatedSpeakerButton({
    super.key,
    required this.onPressed,
    this.isPlaying = false,
    this.size = 32,
    this.primaryColor = AppColors.primary,
    this.playingColor = AppColors.secondary,
  });

  @override
  State<AnimatedSpeakerButton> createState() => _AnimatedSpeakerButtonState();
}

class _AnimatedSpeakerButtonState extends State<AnimatedSpeakerButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.15).animate(
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
    final currentColor = widget.isPlaying ? widget.playingColor : widget.primaryColor;
    
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
                    color: currentColor.withOpacity(0.4),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Icon(
                widget.isPlaying ? Icons.graphic_eq_rounded : Icons.volume_up_rounded,
                color: Colors.white,
                size: widget.size,
              ),
            ),
          );
        },
      ),
    );
  }
}

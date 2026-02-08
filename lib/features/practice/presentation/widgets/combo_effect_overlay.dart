// 显示连击特效的组件
// 功能:
// - 文本缩放和淡出动画
// - 基于连击数改变颜色
// - 使用 flutter_animate
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';

class ComboEffectOverlay extends StatelessWidget {
  final int comboCount;
  final VoidCallback? onAnimationComplete;

  const ComboEffectOverlay({
    super.key,
    required this.comboCount,
    this.onAnimationComplete,
  });

  @override
  Widget build(BuildContext context) {
    if (comboCount < 2) return const SizedBox.shrink();

    String text = "连击 x$comboCount";
    Color color = Colors.orange;
    double fontSize = 40;

    if (comboCount >= 5) {
      text = "无人能挡!\nx$comboCount";
      color = Colors.redAccent;
      fontSize = 50;
    } else if (comboCount >= 3) {
      text = "太棒了!\nx$comboCount";
      color = Colors.deepOrange;
      fontSize = 45;
    }

    return Center(
      child: IgnorePointer(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              text,
              textAlign: TextAlign.center,
              style: GoogleFonts.rubikBubbles(
                fontSize: fontSize,
                color: color,
                shadows: [
                  Shadow(color: Colors.black.withValues(alpha: 0.3), offset: const Offset(4, 4), blurRadius: 8),
                  const Shadow(color: Colors.white, offset: Offset(-2, -2), blurRadius: 4),
                ]
              ),
            )
            .animate(onComplete: (c) => onAnimationComplete?.call())
            .scale(begin: const Offset(0.5, 0.5), end: const Offset(1.2, 1.2), duration: 200.ms, curve: Curves.easeOutBack)
            .then()
            .shake(hz: 4, curve: Curves.easeInOut)
            .moveY(begin: 0, end: -50, duration: 600.ms)
            .fadeOut(duration: 400.ms),
          ],
        ),
      ),
    );
  }
}

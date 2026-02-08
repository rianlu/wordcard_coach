import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../../core/theme/app_colors.dart';

class BattleBackground extends StatelessWidget {
  const BattleBackground({super.key});

  @override
  Widget build(BuildContext context) {
    // Generate some random particles
    final random = Random(42); // Fixed seed for consistent look
    final particles = List.generate(8, (index) {
      final size = random.nextDouble() * 40 + 20;
      final top = random.nextDouble() * 400;
      final left = random.nextDouble() * 300;
      final color = index % 2 == 0 
          ? AppColors.primary.withValues(alpha: 0.05) 
          : AppColors.secondary.withValues(alpha: 0.05);
      final duration = random.nextInt(3000) + 3000;
      
      return Positioned(
        top: top,
        left: left,
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        )
        .animate(onPlay: (c) => c.repeat(reverse: true))
        .moveY(begin: 0, end: -30, duration: duration.ms, curve: Curves.easeInOut)
        .scaleXY(begin: 1, end: 1.2, duration: duration.ms, curve: Curves.easeInOut),
      );
    });

    return Stack(
      children: [
        // Base Gradient
        Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                const Color(0xFFEEF2FF), // Indigo 50
                Colors.white,
              ],
            ),
          ),
        ),
        // Particles
        ...particles,
      ],
    );
  }
}

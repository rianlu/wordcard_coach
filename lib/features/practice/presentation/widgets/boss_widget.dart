import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/theme/app_colors.dart';

class BossWidget extends StatelessWidget {
  final int currentHp;
  final int maxHp;
  final bool isHit;
  final bool isDead;

  const BossWidget({
    super.key,
    required this.currentHp,
    required this.maxHp,
    this.isHit = false,
    this.isDead = false,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // 如果可用高度小于 160，启用紧凑模式 (Compact Mode)
        final isCompact = constraints.maxHeight < 160;

        if (isCompact) {
          return _buildCompactLayout();
        }
        return _buildFullLayout();
      },
    );
  }

  Widget _buildCompactLayout() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 小头像
          Image.asset(
            'assets/images/boss_monster.png',
            width: 48,
            height: 48,
          )
          .animate(target: isHit ? 1 : 0)
          .shake(duration: 400.ms, hz: 4)
          .tint(color: Colors.red.withValues(alpha: 0.5), duration: 200.ms),
          
          const SizedBox(width: 12),
          
          // 血条
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "BOSS HP: $currentHp / $maxHp",
                  style: GoogleFonts.rubik(
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                    color: AppColors.textMediumEmphasis,
                  ),
                ),
                const SizedBox(height: 4),
                SizedBox(
                  height: 12,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: TweenAnimationBuilder<double>(
                       duration: const Duration(milliseconds: 500),
                       curve: Curves.easeOutCirc,
                       tween: Tween<double>(begin: 1.0, end: maxHp > 0 ? (currentHp / maxHp).clamp(0.0, 1.0) : 0.0),
                       builder: (context, value, _) {
                         final color = HSLColor.lerp(
                           HSLColor.fromColor(const Color(0xFFFF5252)), 
                           HSLColor.fromColor(const Color(0xFF4ADE80)), 
                           value
                         )!.toColor();
                         return LinearProgressIndicator(
                           value: value,
                           backgroundColor: Colors.grey.shade300,
                           valueColor: AlwaysStoppedAnimation(color),
                         );
                       },
                     ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFullLayout() {
    // 粘土风格的 Boss 战场容器
    return Column(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // Boss 头像区域
        SizedBox(
          height: 140, // 稍微减小一点以适应更多屏幕
          width: 140,
          child: Stack(
            alignment: Alignment.center,
            clipBehavior: Clip.none,
            children: [
              // Boss 身后的光晕
              Container(
                 width: 120,
                 height: 120,
                 decoration: BoxDecoration(
                   shape: BoxShape.circle,
                   color: AppColors.primary.withValues(alpha: 0.2),
                   boxShadow: [
                     BoxShadow(
                       color: AppColors.primary.withValues(alpha: 0.4),
                       blurRadius: 40,
                       spreadRadius: 10,
                     )
                   ],
                 ),
              )
              .animate(onPlay: (controller) => controller.loop(reverse: true))
              .scale(begin: const Offset(0.9, 0.9), end: const Offset(1.1, 1.1), duration: 2.seconds),

               // Boss 图像 + 呼吸动画 (Idle)
              Image.asset(
                'assets/images/boss_monster.png',
                width: 120,
                height: 120,
                fit: BoxFit.contain,
              )
              .animate(onPlay: (c) => c.repeat(reverse: true))
              .scaleXY(begin: 1.0, end: 1.05, duration: 2.seconds, curve: Curves.easeInOut) // 呼吸
              .animate(target: isHit ? 1 : 0) // 受击状态覆盖
              .shake(duration: 400.ms, hz: 4, curve: Curves.easeInOut) 
              .tint(color: Colors.red.withValues(alpha: 0.5), duration: 200.ms) 
              .animate(target: isDead ? 1 : 0) // 死亡状态
              .fadeOut(duration: 600.ms)
              .scale(begin: const Offset(1, 1), end: const Offset(0, 0)),
              
              // 伤害数字 (受击时弹出)
              if (isHit)
                Positioned(
                  top: -20,
                  right: 0,
                  child: Text(
                    "-1",
                    style: GoogleFonts.rubikBubbles(
                      fontSize: 40,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFFFF5252),
                      shadows: [
                        const Shadow(color: Colors.black26, offset: Offset(2, 2), blurRadius: 4)
                      ]
                    ),
                  )
                  .animate()
                  .moveY(begin: 0, end: -60, duration: 800.ms, curve: Curves.easeOutBack)
                  .fadeOut(delay: 500.ms, duration: 300.ms),
                ),
            ],
          ),
        ),

        const SizedBox(height: 12),

        // 血条容器 (粘土风格)
        Container(
          width: 220,
          height: 28,
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: const Color(0xFFE0E0E0), 
            borderRadius: BorderRadius.circular(14),
            boxShadow: [
              // 新拟态/粘土 内阴影效果
               BoxShadow(
                color: Colors.grey.shade400,
                offset: const Offset(4, 4),
                blurRadius: 8,
                spreadRadius: 1,
              ),
               const BoxShadow(
                color: Colors.white,
                offset: Offset(-4, -4),
                blurRadius: 8,
                spreadRadius: 1,
              ),
            ],
          ),
          child: LayoutBuilder(
            builder: (context, constraints) {
               final double progress = maxHp > 0 ? (currentHp / maxHp).clamp(0.0, 1.0) : 0.0;
               return Stack(
                 children: [
                   // 动画血条
                   TweenAnimationBuilder<double>(
                     duration: const Duration(milliseconds: 500),
                     curve: Curves.easeOutCirc,
                     tween: Tween<double>(begin: 1.0, end: progress),
                     builder: (context, value, _) {
                       // 颜色过渡：红 -> 黄 -> 绿
                       final color = HSLColor.lerp(
                         HSLColor.fromColor(const Color(0xFFFF5252)), 
                         HSLColor.fromColor(const Color(0xFF4ADE80)), 
                         value
                       )!.toColor();
                       
                       return Container(
                         width: constraints.maxWidth * value,
                         height: double.infinity,
                         decoration: BoxDecoration(
                           color: color,
                           borderRadius: BorderRadius.circular(12),
                           boxShadow: [
                             BoxShadow(
                               color: color.withValues(alpha: 0.4),
                               blurRadius: 6,
                               offset: const Offset(0, 2),
                             )
                           ] 
                         ),
                       );
                     },
                   ),
                 ],
               );
            }
          ),
        ),
        
        const SizedBox(height: 8),
        
        Text(
          "BOSS HP: $currentHp / $maxHp",
          style: GoogleFonts.rubik(
            fontSize: 14,
            fontWeight: FontWeight.w900,
            color: AppColors.textMediumEmphasis,
          ),
        ),
      ],
    );
  }
}

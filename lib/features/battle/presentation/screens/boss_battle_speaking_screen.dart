import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../widgets/boss_battle_layout.dart';

class BossBattleSpeakingScreen extends StatelessWidget {
  const BossBattleSpeakingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BossBattleLayout(
      title: 'Boss Battle',
      heroHealth: 0.8,
      bossHealth: 0.1, // Close to winning!
      child: Column(
        children: [
          const Spacer(),
          // Battle Card Style
          Container(
             margin: const EdgeInsets.symmetric(horizontal: 24),
             padding: const EdgeInsets.all(32),
             decoration: BoxDecoration(
               color: Colors.white,
               borderRadius: BorderRadius.circular(32),
               border: Border.all(color: Colors.grey.shade100, width: 2),
               boxShadow: const [
                 BoxShadow(color: Colors.black12, offset: Offset(0,8), blurRadius: 0)
               ]
             ),
             child: Column(
               children: [
                 const Text(
                   'VICTORY',
                   style: TextStyle(fontSize: 36, fontWeight: FontWeight.w900, color: AppColors.textHighEmphasis),
                 ),
                 const SizedBox(height: 8),
                 Container(
                   padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                   decoration: BoxDecoration(
                     color: AppColors.background,
                     borderRadius: BorderRadius.circular(12)
                   ),
                   child: const Text('/ˈvɪk.tər.i/', style: TextStyle(fontSize: 16, color: AppColors.textMediumEmphasis, fontWeight: FontWeight.w600)),
                 ),
               ],
             ),
          ),
          
          const Spacer(),
          
          Container(
            width: double.infinity,
            padding: const EdgeInsets.only(top: 40, bottom: 60),
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(40)),
              boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 20, offset: Offset(0,-5))]
            ),
            child: Column(
              children: [
                GestureDetector(
                  onTap: () {},
                  child: Container(
                    width: 100,
                    height: 100,
                    decoration: BoxDecoration(
                      color: AppColors.bossRed,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 4),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.bossRed.withOpacity(0.4),
                          blurRadius: 24,
                          spreadRadius: 8,
                        ),
                        BoxShadow(
                          color: Colors.red.shade900,
                          offset: const Offset(0, 8),
                          blurRadius: 0
                        )
                      ]
                    ),
                    child: const Icon(Icons.mic, color: Colors.white, size: 48),
                  ),
                ),
                 const SizedBox(height: 24),
                 const Text(
                  'SHOUT TO ATTACK!',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: AppColors.bossRed, letterSpacing: 1.0),
                ),
              ],
            ),
          )
        ],
      ),
    );
  }
}

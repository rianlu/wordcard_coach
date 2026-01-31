import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/bubbly_button.dart';
import '../widgets/boss_battle_layout.dart';

class BossBattleSpellingScreen extends StatelessWidget {
  const BossBattleSpellingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BossBattleLayout(
      title: 'Boss Battle',
      heroHealth: 0.3, // Low health!
      bossHealth: 0.8,
      child: Column(
        children: [
          const Spacer(),
           Container(
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.grey.shade100, width: 2),
              boxShadow: const [
                BoxShadow(color: Colors.black12, offset: Offset(0,6), blurRadius: 0)
              ]
            ),
            child: const Icon(Icons.volume_up, size: 48, color: AppColors.bossRed),
          ),
          const SizedBox(height: 48),

          Container(
             width: double.infinity,
             margin: const EdgeInsets.symmetric(horizontal: 24),
             padding: const EdgeInsets.all(24),
             decoration: BoxDecoration(
               color: Colors.white,
               borderRadius: BorderRadius.circular(24),
               boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 20)]
             ),
             child: Column(
               children: [
                  const Text(
                    'SPELL TO DEFEND!',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: AppColors.bossRed, letterSpacing: 1.0),
                  ),
                  const SizedBox(height: 24),
                  TextField(
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, letterSpacing: 2.0),
                    decoration: InputDecoration(
                      hintText: 'Type answer...',
                      fillColor: AppColors.background,
                      filled: true,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide.none,
                      ),
                      focusedBorder: OutlineInputBorder(
                         borderRadius: BorderRadius.circular(16),
                         borderSide: const BorderSide(color: AppColors.bossRed, width: 2),
                      ),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                    ),
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: BubblyButton(
                      color: AppColors.bossRed,
                      shadowColor: Colors.red.shade900,
                      onPressed: () {},
                      child: const Center(child: Text('CAST SPELL', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: Colors.white))),
                    ),
                  ),
               ],
             ),
          ),
          
          const Spacer(flex: 2),
        ],
      ),
    );
  }
}

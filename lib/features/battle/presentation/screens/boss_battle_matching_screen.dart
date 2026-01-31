import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/bubbly_button.dart';
import '../widgets/boss_battle_layout.dart';

class BossBattleMatchingScreen extends StatelessWidget {
  const BossBattleMatchingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BossBattleLayout(
      title: 'Boss Battle',
      heroHealth: 0.8,
      bossHealth: 0.45,
      child: Column(
        children: [
          // Challenge Area (Central)
          Expanded(
            child: Center(
              child: Stack(
                alignment: Alignment.center,
                children: [
                   Container(
                     width: 300, height: 300,
                     decoration: const BoxDecoration(
                       shape: BoxShape.circle,
                       image: DecorationImage(
                         image: NetworkImage('https://lh3.googleusercontent.com/aida-public/AB6AXuDsf_QV2J-yoIVrpmPmh3f8HSloJMasRSaDMeVkCFd9V7I4Tqq32qT2uomHssujbdJKpJX298__yb1oDodz4rvyfTn7DedO21KCDtgpIIG_AMyBIj8dTr7hSFfosW7JPIyblxurFGaE6fU5hAyq5GGepwBz-Yo904YJ7cDpqOGL1fDsfNYnf5kUIg2VZjkl66h54yM471cQujiHT2yfT3CUDVfvX19AYJ2ExidumzbYzizYTDezefhkHidhslFac9L5cwv2uzKdQFw'),
                        opacity: 0.1,
                         fit: BoxFit.cover,
                       )
                     ),
                   ),
                   Transform.rotate(
                     angle: -0.05,
                     child: Container(
                       padding: const EdgeInsets.all(32),
                       decoration: BoxDecoration(
                         color: Colors.white,
                         borderRadius: BorderRadius.circular(32),
                         border: Border.all(color: Colors.grey.shade100, width: 2),
                         boxShadow: const [
                           BoxShadow(color: Colors.black12, offset: Offset(0,6), blurRadius: 0)
                         ]
                       ),
                       child: Column(
                         mainAxisSize: MainAxisSize.min,
                         children: [
                             const Align(
                               alignment: Alignment.topRight,
                               child: Icon(Icons.volume_up, color: AppColors.primary),
                             ),
                             const Text(
                               'CHALLENGE', 
                               style: TextStyle(fontSize: 32, fontWeight: FontWeight.w900, letterSpacing: -1.0)
                             ),
                             const SizedBox(height: 8),
                             Container(
                               padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                               decoration: BoxDecoration(
                                 color: AppColors.background,
                                 borderRadius: BorderRadius.circular(16),
                                 border: Border.all(color: Colors.grey.shade200)
                               ),
                               child: const Text('/ˈtʃæl.ɪndʒ/', style: TextStyle(color: AppColors.textMediumEmphasis, fontWeight: FontWeight.w500)),
                             )
                         ],
                       ),
                     ),
                   )
                ],
              ),
            ),
          ),
          
          // Bottom Options Area
          Container(
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 48),
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(40)),
              boxShadow: [
                BoxShadow(color: Colors.black12, blurRadius: 30, offset: Offset(0, -8))
              ]
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Center(
                  child: Text(
                    'CHOOSE THE CORRECT ANSWER',
                    style: TextStyle(
                      fontSize: 12, 
                      fontWeight: FontWeight.w800, 
                      color: AppColors.textMediumEmphasis, 
                      letterSpacing: 1.5
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                _buildOptionBtn('挑战 / 难题'),
                const SizedBox(height: 12),
                _buildOptionBtn('机会 / 巧合'),
                const SizedBox(height: 12),
                 _buildOptionBtn('变化 / 调整'),
                 const SizedBox(height: 12),
                _buildOptionBtn('成功 / 结果'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOptionBtn(String text) {
    return BubblyButton(
      onPressed: () {},
      color: AppColors.primary,
      shadowColor: AppColors.shadowBlue,
      child: Center(
        child: Text(text, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
      ),
    );
  }
}

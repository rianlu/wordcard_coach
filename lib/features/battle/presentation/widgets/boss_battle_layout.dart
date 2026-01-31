import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';

class BossBattleLayout extends StatelessWidget {
  final Widget child;
  final String title;
  final double heroHealth; // 0.0 to 1.0
  final double bossHealth; // 0.0 to 1.0
  final String heroName;
  final String bossName;

  const BossBattleLayout({
    super.key,
    required this.child,
    required this.title,
    this.heroHealth = 0.8,
    this.bossHealth = 0.45,
    this.heroName = 'Hero',
    this.bossName = 'Boss',
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            _buildAppBar(context),
            _buildHeaderStats(),
            Expanded(child: child),
          ],
        ),
      ),
    );
  }

  Widget _buildAppBar(BuildContext context) {
     return Padding(
       padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
       child: Row(
         mainAxisAlignment: MainAxisAlignment.spaceBetween,
         children: [
            InkWell(
              onTap: () {
                if(Navigator.canPop(context)) Navigator.pop(context);
              },
              child: const Icon(Icons.close, color: AppColors.textHighEmphasis, size: 28),
            ),
            Text(
              'BOSS BATTLE',
              style: const TextStyle(
                fontFamily: 'Plus Jakarta Sans',
                fontSize: 18, 
                fontWeight: FontWeight.w900, 
                fontStyle: FontStyle.italic,
                letterSpacing: 1.0,
              ),
            ),
             const Icon(Icons.help_outline, color: AppColors.textHighEmphasis, size: 28),
         ],
       ),
     );
  }

  Widget _buildHeaderStats() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Hero Side
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(heroName.toUpperCase(), style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w900)),
                    Text('${(heroHealth * 100).toInt()}%', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: AppColors.heroGreen)),
                  ],
                ),
                const SizedBox(height: 4),
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: LinearProgressIndicator(
                    value: heroHealth,
                    color: AppColors.heroGreen,
                    backgroundColor: Colors.grey.shade300,
                    minHeight: 12,
                  ),
                ),
              ],
            ),
          ),
          
          // Timer (Top Center)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.secondary,
                borderRadius: BorderRadius.circular(12),
                border: const Border(bottom: BorderSide(color: Color(0xFFb45309), width: 4)), // Darker yellow/orange shadow
                 boxShadow: const [
                   BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(0,2))
                 ]
              ),
              child: const Text('00:15', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
            ),
          ),

          // Boss Side
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                 Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('${(bossHealth * 100).toInt()}%', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: AppColors.bossRed)),
                     Text(bossName.toUpperCase(), style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w900)),
                  ],
                ),
                const SizedBox(height: 4),
                 // Flip the direction for Boss? Or just right aligned
                 Transform.scale(
                   scaleX: -1,
                   child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: LinearProgressIndicator(
                      value: bossHealth,
                      color: AppColors.bossRed,
                      backgroundColor: Colors.grey.shade300,
                      minHeight: 12,
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
}

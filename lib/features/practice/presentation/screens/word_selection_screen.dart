import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/bubbly_button.dart';

class WordSelectionScreen extends StatelessWidget {
  const WordSelectionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('Lesson 12', style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 16),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: AppColors.secondary.withOpacity(0.2),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppColors.secondary.withOpacity(0.3)),
            ),
            child: const Row(
              children: [
                Icon(Icons.stars, color: AppColors.secondary, size: 20),
                SizedBox(width: 4),
                Text('120 XP', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
              ],
            ),
          )
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          children: [
            // Word Card
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: Colors.grey.shade100),
                boxShadow: const [
                  BoxShadow(color: AppColors.shadowWhite, offset: Offset(0,4), blurRadius: 0),
                  BoxShadow(color: Colors.black12, offset: Offset(0, 4), blurRadius: 20, spreadRadius: -2)
                ]
              ),
              child: Column(
                children: [
                   // Image Placeholder
                   Container(
                     height: 180,
                     decoration: BoxDecoration(
                       color: Colors.grey.shade100,
                       borderRadius: BorderRadius.circular(16),
                       image: const DecorationImage(
                          image: NetworkImage('https://lh3.googleusercontent.com/aida-public/AB6AXuCDBymxy7qPY9zCgzSGficR5l_06WvrlthK4z9Laa1YC04TT1UIUlEPmXeaLCdfI4VreuS4qruobJQ9lFDxeBd4oL_cPyfbtZ26e8hfsWFijDqNxfyCBFGd6UPvDmUfnlYPKc6tlmKYghR1O7KUD1QybdNYKxjz_GGJf_WuVPYvN9zALLTAoMZ-1XOdle_NruLKUZNme-WtQNdFbhFS92VwpaeGDkJZJZcpQR0uQdU3RyN4KVznFgRQmR8PUpHlpIXcuLi6zEVzzfM'),
                          fit: BoxFit.cover,
                       ),
                     ),
                     alignment: Alignment.bottomRight,
                     child: Padding(
                       padding: const EdgeInsets.all(12),
                       child: CircleAvatar(
                         backgroundColor: Colors.white,
                         child: IconButton(
                           icon: const Icon(Icons.volume_up, color: AppColors.primary),
                           onPressed: () {},
                         ),
                       ),
                     ),
                   ),
                   const SizedBox(height: 24),
                   const Text('Enthusiastic', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: AppColors.primary)),
                   const Text('/ɪnˌθuːziˈæstɪk/', style: TextStyle(fontSize: 18, color: AppColors.textMediumEmphasis, fontWeight: FontWeight.w500)),
                ],
              ),
            ),
            
            const SizedBox(height: 32),
            const Align(
              alignment: Alignment.centerLeft, 
              child: Text('SELECT THE CORRECT MEANING', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: AppColors.textMediumEmphasis, letterSpacing: 1.0))
            ),
             const SizedBox(height: 16),
             
             _buildOption(context, 'A. 悲伤 (Sad)'),
             const SizedBox(height: 12),
             _buildOption(context, 'B. 热情 (Enthusiastic)', isCorrect: true),
             const SizedBox(height: 12),
             _buildOption(context, 'C. 愤怒 (Angry)'),
             const SizedBox(height: 12),
             _buildOption(context, 'D. 疲倦 (Tired)'),
            
          ],
        ),
      ),
    );
  }

  Widget _buildOption(BuildContext context, String text, {bool isCorrect = false}) {
    return BubblyButton(
      onPressed: () {},
      color: Colors.white,
      shadowColor: Colors.grey.shade200,
      shadowHeight: 4,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(text, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppColors.textHighEmphasis)),
           Container(
             width: 24, height: 24,
             decoration: BoxDecoration(
               shape: BoxShape.circle,
               border: Border.all(color: Colors.grey.shade300, width: 2),
             ),
             child: isCorrect ? const Center(child: Icon(Icons.check, size: 16, color: AppColors.primary)) : null,
           )
        ],
      )
    );
  }
}

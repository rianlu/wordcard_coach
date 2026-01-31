import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';

class SpeakingPracticeScreen extends StatelessWidget {
  const SpeakingPracticeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Speaking Practice')),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          children: [
            // Word Card
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(32),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: Colors.grey.shade100),
                boxShadow: const [
                  BoxShadow(color: AppColors.shadowWhite, offset: Offset(0,4), blurRadius: 0)
                ]
              ),
              child: Column(
                children: [
                   Container(
                     padding: const EdgeInsets.all(16),
                     decoration: BoxDecoration(
                       color: AppColors.primary.withOpacity(0.1),
                       shape: BoxShape.circle,
                     ),
                     child: const Icon(Icons.volume_up, color: AppColors.primary, size: 32),
                   ),
                   const SizedBox(height: 24),
                   const Text('Enthusiastic', style: TextStyle(fontSize: 32, fontWeight: FontWeight.w900, color: AppColors.textHighEmphasis)),
                   const Text('/ɪnˌθuːziˈæstɪk/', style: TextStyle(fontSize: 18, color: AppColors.textMediumEmphasis, fontWeight: FontWeight.w500)),
                   const SizedBox(height: 32),
                   const Text(
                     '“She was very enthusiastic about the idea.”',
                     textAlign: TextAlign.center,
                     style: TextStyle(fontSize: 16, color: AppColors.textHighEmphasis, fontStyle: FontStyle.italic),
                   ),
                ],
              ),
            ),
            
            const Spacer(),
            
            // Microphone Button
            GestureDetector(
              onTap: () {},
              child: Container(
                width: 88,
                height: 88,
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primary.withOpacity(0.4),
                      blurRadius: 24,
                      offset: const Offset(0, 8),
                    ),
                    const BoxShadow(
                      color: AppColors.shadowBlue,
                      offset: Offset(0, 6),
                      blurRadius: 0,
                    )
                  ]
                ),
                child: const Icon(Icons.mic, color: Colors.white, size: 40),
              ),
            ),
            const SizedBox(height: 16),
            const Text('Tap to Speak', style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.textMediumEmphasis)),
            const SizedBox(height: 48),
          ],
        ),
      ),
    );
  }
}

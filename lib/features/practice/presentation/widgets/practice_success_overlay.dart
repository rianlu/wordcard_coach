import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/database/models/word.dart';

class PracticeSuccessOverlay extends StatelessWidget {
  final Word word;
  final String title;
  final String? subtitle;

  const PracticeSuccessOverlay({
    super.key,
    required this.word,
    this.title = 'Great Job!',
    this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: Container(
        color: Colors.black54, // Dim background
        child: Center(
          child: TweenAnimationBuilder<double>(
            tween: Tween(begin: 0.0, end: 1.0),
            duration: const Duration(milliseconds: 400),
            curve: Curves.easeOutQuint, // Smooth, non-bouncy
            builder: (context, value, child) {
              return Transform.scale(
                scale: 0.9 + (0.1 * value), // Subtle zoom 0.9 -> 1.0
                child: Opacity(
                  opacity: value,
                  child: child,
                ),
              );
            },
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Container(
                width: double.infinity,
                margin: const EdgeInsets.symmetric(horizontal: 24),
                padding: const EdgeInsets.fromLTRB(32, 40, 32, 32),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: const [
                    BoxShadow(color: AppColors.shadowWhite, offset: Offset(0, 8), blurRadius: 16),
                    BoxShadow(color: Colors.black26, offset: Offset(0, 4), blurRadius: 10),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Icon
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.check_rounded, color: AppColors.primary, size: 40),
                    ),
                    const SizedBox(height: 24),

                    // Header
                    Text(
                      title,
                      textAlign: TextAlign.center,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 24,
                        fontWeight: FontWeight.w900,
                        color: AppColors.textHighEmphasis,
                      ),
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFEF3C7), // Yellow 100
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: const Color(0xFFFCD34D), width: 1.5),
                        ),
                        child: Text(
                          subtitle!,
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                            color: const Color(0xFFD97706),
                            letterSpacing: 0.5
                          ),
                        ),
                      ),
                    ],

                    const SizedBox(height: 32),

                    // Word & Meaning
                    Text(
                      word.text,
                      textAlign: TextAlign.center,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 32,
                        fontWeight: FontWeight.w900,
                        color: AppColors.primary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      word.phonetic,
                      style: GoogleFonts.notoSans(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                        color: AppColors.textMediumEmphasis,
                      ),
                    ),
                    
                    const SizedBox(height: 40),
                    
                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/theme/app_colors.dart';

class HighlightCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final String badgeText;
  final int colorValue; // ARGB int
  final int iconCode;

  const HighlightCard({
    super.key,
    required this.title,
    required this.subtitle,
    required this.badgeText,
    required this.colorValue,
    required this.iconCode,
  });

  @override
  Widget build(BuildContext context) {
    // Reconstruct Color
    final color = Color(colorValue);
    final iconData = IconData(iconCode, fontFamily: 'MaterialIcons');

    return Container(
      height: 180, // Fixed height to allow Spacer() to work
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08), // Very light background tint
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: color.withOpacity(0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Icon Circle
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: color.withOpacity(0.2),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                )
              ],
            ),
            child: Icon(iconData, color: color, size: 24),
          ),
          const Spacer(),
          
          Text(
             subtitle,
             style: GoogleFonts.notoSans(
               fontSize: 14, 
               fontWeight: FontWeight.bold, 
               color: color
             )
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 20,
              fontWeight: FontWeight.w900,
              color: AppColors.textHighEmphasis,
            ),
             maxLines: 1,
             overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 12),
          
          // Badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
               boxShadow: [
                BoxShadow(
                  color: color.withOpacity(0.1),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                )
              ],
            ),
            child: Text(
              badgeText,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          )
        ],
      ),
    );
  }
}

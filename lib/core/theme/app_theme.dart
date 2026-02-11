import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app_colors.dart';

class AppTheme {
  static final ThemeData lightTheme = ThemeData(
    useMaterial3: true,
    fontFamily: GoogleFonts.plusJakartaSans().fontFamily,
    colorScheme: ColorScheme.fromSeed(
      seedColor: AppColors.primary,
      primary: AppColors.primary,
      secondary: AppColors.secondary,
      surface: AppColors.surface,
      // 逻辑处理
    ),
    scaffoldBackgroundColor: AppColors.background,
    
    // 逻辑处理
    cardTheme: CardThemeData(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20), // 逻辑处理
        side: const BorderSide(color: AppColors.shadowWhite, width: 1),
      ),
      color: Colors.white,
    ),

    // 逻辑处理
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 0, // 逻辑处理
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        textStyle: GoogleFonts.plusJakartaSans(
          fontSize: 16,
          fontWeight: FontWeight.w700,
        ),
      ),
    ),
    
    // 逻辑处理
    appBarTheme: const AppBarTheme(
      backgroundColor: AppColors.surface,
      foregroundColor: AppColors.textHighEmphasis,
      elevation: 0,
      centerTitle: true,
      scrolledUnderElevation: 0,
      titleTextStyle: TextStyle(
         color: AppColors.textHighEmphasis,
         fontSize: 18,
         fontWeight: FontWeight.w700,
         fontFamily: 'Plus Jakarta Sans' // 逻辑处理
      )
    ),
  );
}

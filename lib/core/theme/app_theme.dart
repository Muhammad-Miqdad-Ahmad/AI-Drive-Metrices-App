import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app_colors.dart';

class AppTheme {
  static ThemeData purpleTheme = ThemeData(
    useMaterial3: true,
    scaffoldBackgroundColor: AppColors.background,
    brightness: Brightness.light,

    // Primary Color configuration
    primaryColor: AppColors.primaryPurple,
    colorScheme: ColorScheme.fromSeed(
      seedColor: AppColors.primaryPurple,
      primary: AppColors.primaryPurple,
      secondary: AppColors.accentPurple,
    ),

    // Text Theme updated for light background
    textTheme: GoogleFonts.poppinsTextTheme().apply(
      bodyColor: AppColors.textPrimary,
      displayColor: AppColors.textPrimary,
    ),

    // Button Theme to match the "Log in" purple button
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.primaryPurple,
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        padding: const EdgeInsets.symmetric(vertical: 16),
      ),
    ),
  );
}

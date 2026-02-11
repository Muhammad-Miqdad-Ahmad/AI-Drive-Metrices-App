import 'package:flutter/material.dart';

class AppColors {
  // Primary Backgrounds
  static const Color background = Color(0xFFF8F9FE);
  static const Color primaryPurple = Color(0xFF8E44AD);
  static const Color accentPurple = Color(0xFFBE93E7);

  // Card & Surface Colors
  static const Color cardWhite = Colors.white;
  static const Color cardDark = Color(
    0xFF2D3436,
  ); // Keep a dark variant for specific UI elements

  // UI Accents
  static const Color primary = Color(0xFF8E44AD);
  static const Color accent = Color(0xFFBE93E7);

  // Text Colors
  static const Color textPrimary = Color(0xFF2D3436);
  static const Color textSecondary = Color(0xFF636E72);

  static const LinearGradient purpleGradient = LinearGradient(
    colors: [Color(0xFF8E44AD), Color(0xFFBE93E7)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
}

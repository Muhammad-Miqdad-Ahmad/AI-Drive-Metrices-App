import 'package:flutter/material.dart';

class AppColors {
  AppColors._();

  // Primary Brand
  static const Color primary = Color(0xFF0057FF); // Electric blue
  static const Color primaryLight = Color(0xFF4D8BFF);
  static const Color primaryDark = Color(0xFF003DB8);
  static const Color primarySurface = Color(0xFFEEF3FF); // very light blue tint

  // Accent / Safety Green
  static const Color accent = Color(0xFF00C48C);
  static const Color accentLight = Color(0xFFE0FAF3);

  // Semantic colors
  static const Color danger = Color(0xFFFF3B30);
  static const Color dangerLight = Color(0xFFFFEEED);
  static const Color warning = Color(0xFFFF9500);
  static const Color warningLight = Color(0xFFFFF3E0);
  static const Color success = Color(0xFF34C759);
  static const Color successLight = Color(0xFFEAF9EE);

  // Neutrals (light theme)
  static const Color background = Color(0xFFF7F9FC);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color surfaceVariant = Color(0xFFF0F2F7);
  static const Color border = Color(0xFFE4E8F0);
  static const Color borderLight = Color(0xFFF0F2F7);

  // Text
  static const Color textPrimary = Color(0xFF0D1B3E);
  static const Color textSecondary = Color(0xFF5A6B8A);
  static const Color textTertiary = Color(0xFF9BACC8);
  static const Color textOnPrimary = Color(0xFFFFFFFF);

  // Gradients
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [Color(0xFF0057FF), Color(0xFF4D8BFF)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient dashboardHeaderGradient = LinearGradient(
    colors: [Color(0xFF0A2463), Color(0xFF0057FF)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient safeGradient = LinearGradient(
    colors: [Color(0xFF00C48C), Color(0xFF00E6A8)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  // Score color helper
  static Color scoreColor(double score) {
    if (score >= 80) return success;
    if (score >= 60) return warning;
    return danger;
  }

  static Color scoreColorLight(double score) {
    if (score >= 80) return successLight;
    if (score >= 60) return warningLight;
    return dangerLight;
  }

  // Shadow
  static List<BoxShadow> cardShadow = [
    BoxShadow(
      color: const Color(0xFF0057FF).withValues(alpha: 0.06),
      blurRadius: 20,
      offset: const Offset(0, 4),
    ),
    BoxShadow(
      color: Colors.black.withValues(alpha: 0.04),
      blurRadius: 8,
      offset: const Offset(0, 2),
    ),
  ];

  static List<BoxShadow> primaryShadow = [
    BoxShadow(
      color: primary.withValues(alpha: 0.30),
      blurRadius: 16,
      offset: const Offset(0, 6),
    ),
  ];
}

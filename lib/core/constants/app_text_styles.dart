import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'app_colors.dart';

class AppTextStyles {
  AppTextStyles._();

  // Display — for hero numbers, big scores
  static TextStyle get display1 => TextStyle(
        fontFamily: 'DMSans',
        fontSize: 56.sp,
        fontWeight: FontWeight.w800,
        color: AppColors.textPrimary,
        letterSpacing: -2.0,
        height: 1.0,
      );

  static TextStyle get display2 => TextStyle(
        fontFamily: 'DMSans',
        fontSize: 40.sp,
        fontWeight: FontWeight.w700,
        color: AppColors.textPrimary,
        letterSpacing: -1.5,
        height: 1.1,
      );

  // Headings
  static TextStyle get h1 => TextStyle(
        fontFamily: 'DMSans',
        fontSize: 28.sp,
        fontWeight: FontWeight.w700,
        color: AppColors.textPrimary,
        letterSpacing: -0.8,
        height: 1.2,
      );

  static TextStyle get h2 => TextStyle(
        fontFamily: 'DMSans',
        fontSize: 22.sp,
        fontWeight: FontWeight.w700,
        color: AppColors.textPrimary,
        letterSpacing: -0.5,
        height: 1.25,
      );

  static TextStyle get h3 => TextStyle(
        fontFamily: 'DMSans',
        fontSize: 18.sp,
        fontWeight: FontWeight.w600,
        color: AppColors.textPrimary,
        letterSpacing: -0.3,
        height: 1.3,
      );

  static TextStyle get h4 => TextStyle(
        fontFamily: 'DMSans',
        fontSize: 16.sp,
        fontWeight: FontWeight.w600,
        color: AppColors.textPrimary,
        letterSpacing: -0.2,
        height: 1.35,
      );

  // Body
  static TextStyle get bodyLarge => TextStyle(
        fontFamily: 'DMSans',
        fontSize: 16.sp,
        fontWeight: FontWeight.w400,
        color: AppColors.textPrimary,
        height: 1.6,
      );

  static TextStyle get bodyMedium => TextStyle(
        fontFamily: 'DMSans',
        fontSize: 14.sp,
        fontWeight: FontWeight.w400,
        color: AppColors.textSecondary,
        height: 1.6,
      );

  static TextStyle get bodySmall => TextStyle(
        fontFamily: 'DMSans',
        fontSize: 12.sp,
        fontWeight: FontWeight.w400,
        color: AppColors.textTertiary,
        height: 1.5,
      );

  // Labels
  static TextStyle get labelLarge => TextStyle(
        fontFamily: 'DMSans',
        fontSize: 14.sp,
        fontWeight: FontWeight.w600,
        color: AppColors.textPrimary,
        letterSpacing: 0.1,
      );

  static TextStyle get labelMedium => TextStyle(
        fontFamily: 'DMSans',
        fontSize: 12.sp,
        fontWeight: FontWeight.w600,
        color: AppColors.textSecondary,
        letterSpacing: 0.2,
      );

  static TextStyle get labelSmall => TextStyle(
        fontFamily: 'DMSans',
        fontSize: 11.sp,
        fontWeight: FontWeight.w500,
        color: AppColors.textTertiary,
        letterSpacing: 0.5,
      );

  // Mono — for data values, OBD metrics
  static TextStyle get monoLarge => TextStyle(
        fontFamily: 'DMMono',
        fontSize: 24.sp,
        fontWeight: FontWeight.w500,
        color: AppColors.textPrimary,
        letterSpacing: -0.5,
      );

  static TextStyle get monoMedium => TextStyle(
        fontFamily: 'DMMono',
        fontSize: 16.sp,
        fontWeight: FontWeight.w400,
        color: AppColors.textPrimary,
      );

  static TextStyle get monoSmall => TextStyle(
        fontFamily: 'DMMono',
        fontSize: 12.sp,
        fontWeight: FontWeight.w400,
        color: AppColors.textSecondary,
      );

  // Button
  static TextStyle get buttonLarge => TextStyle(
        fontFamily: 'DMSans',
        fontSize: 16.sp,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.2,
      );

  static TextStyle get buttonMedium => TextStyle(
        fontFamily: 'DMSans',
        fontSize: 14.sp,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.1,
      );

  // Caption / overline
  static TextStyle get caption => TextStyle(
        fontFamily: 'DMSans',
        fontSize: 11.sp,
        fontWeight: FontWeight.w500,
        color: AppColors.textTertiary,
        letterSpacing: 0.8,
      );

  static TextStyle get overline => TextStyle(
        fontFamily: 'DMSans',
        fontSize: 10.sp,
        fontWeight: FontWeight.w600,
        color: AppColors.textTertiary,
        letterSpacing: 1.5,
      );
}

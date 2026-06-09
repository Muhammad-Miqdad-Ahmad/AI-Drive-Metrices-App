import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_text_styles.dart';
import '../../core/services/mock_data_service.dart';
import '../../core/utils/date_formatter.dart';
import '../../widgets/common/score_gauge_widget.dart';
import '../../widgets/common/stat_card_widget.dart';

class VehicleHealthScreen extends StatelessWidget {
  const VehicleHealthScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final health = MockDataService.vehicleHealth;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Vehicle Health'),
        backgroundColor: AppColors.surface,
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(20.r),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Overall health card
            _OverallHealthCard(health: health),
            SizedBox(height: 20.h),

            // Health metrics
            Text('Component Health', style: AppTextStyles.h3),
            SizedBox(height: 4.h),
            Text(
              'Updated ${DateFormatter.relativeTime(health.lastUpdated)}',
              style: AppTextStyles.bodySmall,
            ),
            SizedBox(height: 16.h),
            Container(
              padding: EdgeInsets.all(20.r),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(16.r),
                border: Border.all(color: AppColors.border),
                boxShadow: AppColors.cardShadow,
              ),
              child: Column(
                children: [
                  HealthBar(
                    label: 'Engine Health',
                    value: health.engineHealth,
                    icon: Icons.settings_rounded,
                  ),
                  SizedBox(height: 20.h),
                  HealthBar(
                    label: 'Brake Wear',
                    value: health.brakeWear,
                    icon: Icons.disc_full_rounded,
                  ),
                  SizedBox(height: 20.h),
                  HealthBar(
                    label: 'Suspension Stress',
                    value: health.suspensionStress,
                    icon: Icons.directions_car_filled_rounded,
                  ),
                  SizedBox(height: 20.h),
                  HealthBar(
                    label: 'Tyre Pressure Score',
                    value: health.tyrePressureScore,
                    icon: Icons.tire_repair_rounded,
                  ),
                ],
              ),
            ),
            SizedBox(height: 20.h),

            // Insights
            Text('Insights & Recommendations', style: AppTextStyles.h3),
            SizedBox(height: 12.h),
            ...health.insights.map((insight) => Padding(
                  padding: EdgeInsets.only(bottom: 12.h),
                  child: _InsightCard(insight: insight),
                )),
            SizedBox(height: 20.h),

            // How driving affects health
            _DrivingImpactCard(),
            SizedBox(height: 32.h),
          ],
        ),
      ),
    );
  }
}

class _OverallHealthCard extends StatelessWidget {
  final dynamic health;
  const _OverallHealthCard({required this.health});

  @override
  Widget build(BuildContext context) {
    final score = health.overall as double;
    final color = AppColors.scoreColor(score);

    return Container(
      padding: EdgeInsets.all(20.r),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20.r),
        border: Border.all(color: AppColors.border),
        boxShadow: AppColors.cardShadow,
      ),
      child: Row(
        children: [
          ScoreGaugeWidget(score: score, size: 110, showLabel: true),
          SizedBox(width: 20.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Overall Health', style: AppTextStyles.labelMedium),
                SizedBox(height: 6.h),
                Text(
                  _healthLabel(score),
                  style: AppTextStyles.h2.copyWith(color: color),
                ),
                SizedBox(height: 8.h),
                Text(
                  'Based on your last ${MockDataService.trips.length} trips and driving behaviour analysis.',
                  style: AppTextStyles.bodySmall,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _healthLabel(double score) {
    if (score >= 80) return 'Healthy';
    if (score >= 60) return 'Moderate';
    return 'Needs Attention';
  }
}

class _InsightCard extends StatelessWidget {
  final dynamic insight;
  const _InsightCard({required this.insight});

  Color get _color {
    switch (insight.severity as String) {
      case 'warning':
        return AppColors.warning;
      case 'critical':
        return AppColors.danger;
      default:
        return AppColors.primary;
    }
  }

  Color get _bgColor {
    switch (insight.severity as String) {
      case 'warning':
        return AppColors.warningLight;
      case 'critical':
        return AppColors.dangerLight;
      default:
        return AppColors.primarySurface;
    }
  }

  IconData get _icon {
    switch (insight.severity as String) {
      case 'warning':
        return Icons.warning_amber_rounded;
      case 'critical':
        return Icons.error_outline_rounded;
      default:
        return Icons.info_outline_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(16.r),
      decoration: BoxDecoration(
        color: _bgColor,
        borderRadius: BorderRadius.circular(14.r),
        border: Border.all(color: _color.withValues(alpha: 0.3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(_icon, size: 20.r, color: _color),
          SizedBox(width: 12.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  insight.title as String,
                  style: AppTextStyles.labelLarge.copyWith(color: _color),
                ),
                SizedBox(height: 4.h),
                Text(
                  insight.description as String,
                  style: AppTextStyles.bodySmall,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DrivingImpactCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(20.r),
      decoration: BoxDecoration(
        gradient: AppColors.primaryGradient,
        borderRadius: BorderRadius.circular(16.r),
        boxShadow: AppColors.primaryShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.lightbulb_outline_rounded,
                  color: Colors.white, size: 20.r),
              SizedBox(width: 8.w),
              Text(
                'Did You Know?',
                style: AppTextStyles.h4.copyWith(color: Colors.white),
              ),
            ],
          ),
          SizedBox(height: 10.h),
          Text(
            'Reducing harsh braking events by 50% can extend your brake pad life by up to 30%. '
            'Smooth acceleration also reduces engine wear significantly.',
            style: AppTextStyles.bodyMedium
                .copyWith(color: Colors.white.withValues(alpha: 0.85)),
          ),
        ],
      ),
    );
  }
}

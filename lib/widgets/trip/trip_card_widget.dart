import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_text_styles.dart';
import '../../core/utils/date_formatter.dart';
import '../../models/models.dart';
import '../common/score_gauge_widget.dart';
import '../common/stat_card_widget.dart';

class TripCard extends StatelessWidget {
  final TripModel trip;
  final VoidCallback? onTap;

  const TripCard({super.key, required this.trip, this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.all(16.r),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16.r),
          border: Border.all(color: AppColors.border),
          boxShadow: AppColors.cardShadow,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header row
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        DateFormatter.tripDate(trip.startTime),
                        style: AppTextStyles.labelLarge,
                      ),
                      SizedBox(height: 2.h),
                      Text(
                        '${trip.distanceKm.toStringAsFixed(1)} km • ${trip.durationLabel}',
                        style: AppTextStyles.bodySmall,
                      ),
                    ],
                  ),
                ),
                ScoreBadge(score: trip.score.overall),
              ],
            ),
            SizedBox(height: 12.h),
            // Stats row
            Row(
              children: [
                _MiniStat(
                  icon: Icons.speed_rounded,
                  value: '${trip.maxSpeedKmh.toInt()}',
                  unit: 'km/h',
                  label: 'Max',
                ),
                SizedBox(width: 16.w),
                _MiniStat(
                  icon: Icons.speed_outlined,
                  value: '${trip.avgSpeedKmh.toInt()}',
                  unit: 'km/h',
                  label: 'Avg',
                ),
              ],
            ),
            // Events row (if any)
            if (trip.events.isNotEmpty) ...[
              SizedBox(height: 10.h),
              const Divider(height: 1),
              SizedBox(height: 10.h),
              Wrap(
                spacing: 6.w,
                runSpacing: 6.h,
                children: _buildEventBadges(trip),
              ),
            ],
          ],
        ),
      ),
    );
  }

  List<Widget> _buildEventBadges(TripModel trip) {
    final Map<TripEventType, int> counts = {};
    for (final e in trip.events) {
      counts[e.type] = (counts[e.type] ?? 0) + 1;
    }
    return counts.entries.map((entry) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          EventBadge(type: entry.key, compact: true),
          if (entry.value > 1) ...[
            SizedBox(width: 3.w),
            Container(
              padding: EdgeInsets.symmetric(horizontal: 5.w, vertical: 2.h),
              decoration: BoxDecoration(
                color: AppColors.surfaceVariant,
                borderRadius: BorderRadius.circular(6.r),
              ),
              child: Text(
                'x${entry.value}',
                style: AppTextStyles.overline,
              ),
            ),
          ],
        ],
      );
    }).toList();
  }
}

class _MiniStat extends StatelessWidget {
  final IconData icon;
  final String value;
  final String unit;
  final String label;

  const _MiniStat({
    required this.icon,
    required this.value,
    required this.unit,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14.r, color: AppColors.textTertiary),
        SizedBox(width: 4.w),
        Text(
          '$value $unit',
          style: AppTextStyles.monoSmall,
        ),
        SizedBox(width: 3.w),
        Text(label, style: AppTextStyles.bodySmall),
      ],
    );
  }
}

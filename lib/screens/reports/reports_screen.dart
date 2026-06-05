import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_text_styles.dart';
import '../../core/services/mock_data_service.dart';
import '../../core/utils/date_formatter.dart';
import '../../models/models.dart';
import '../../widgets/common/score_gauge_widget.dart';

class ReportsScreen extends StatelessWidget {
  const ReportsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final trips = MockDataService.trips;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Trip Reports'),
        backgroundColor: AppColors.surface,
        actions: [
          TextButton.icon(
            onPressed: () {},
            icon: const Icon(Icons.filter_list_rounded, size: 18),
            label: const Text('Filter'),
          ),
        ],
      ),
      body: ListView.separated(
        padding: const EdgeInsets.all(20),
        itemCount: trips.length,
        separatorBuilder: (_, __) => const SizedBox(height: 14),
        itemBuilder: (context, index) => _ReportCard(trip: trips[index]),
      ),
    );
  }
}

class _ReportCard extends StatelessWidget {
  final TripModel trip;
  const _ReportCard({required this.trip});

  @override
  Widget build(BuildContext context) {
    final score = trip.score.overall;
    final color = AppColors.scoreColor(score);

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
        boxShadow: AppColors.cardShadow,
      ),
      child: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.scoreColorLight(score),
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(16)),
            ),
            child: Row(
              children: [
                ScoreBadge(score: score, size: 52),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Trip Report',
                        style: AppTextStyles.labelLarge,
                      ),
                      Text(
                        DateFormatter.fullDateTime(trip.startTime),
                        style: AppTextStyles.bodySmall,
                      ),
                    ],
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    'Grade ${trip.score.grade}',
                    style: AppTextStyles.labelMedium.copyWith(color: color),
                  ),
                ),
              ],
            ),
          ),

          // Stats
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                _ReportRow(
                  label: 'Distance',
                  value: '${trip.distanceKm.toStringAsFixed(1)} km',
                  icon: Icons.route_rounded,
                ),
                _ReportRow(
                  label: 'Duration',
                  value: trip.durationLabel,
                  icon: Icons.timer_outlined,
                ),
                _ReportRow(
                  label: 'Max Speed',
                  value: '${trip.maxSpeedKmh.toInt()} km/h',
                  icon: Icons.speed_rounded,
                ),
                _ReportRow(
                  label: 'Events',
                  value: '${trip.events.length} detected',
                  icon: Icons.warning_amber_rounded,
                  valueColor: trip.events.isEmpty
                      ? AppColors.success
                      : AppColors.warning,
                ),
                _ReportRow(
                  label: 'Harsh Braking',
                  value: '${trip.harshBrakingCount}x',
                  icon: Icons.car_crash_rounded,
                  valueColor: trip.harshBrakingCount == 0
                      ? AppColors.success
                      : AppColors.danger,
                ),
                _ReportRow(
                  label: 'Sharp Turns',
                  value: '${trip.sharpTurnCount}x',
                  icon: Icons.turn_right_rounded,
                  valueColor: trip.sharpTurnCount == 0
                      ? AppColors.success
                      : AppColors.warning,
                ),
              ],
            ),
          ),

          // Actions
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {},
                    icon: const Icon(Icons.download_outlined, size: 16),
                    label: const Text('Download'),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(0, 42),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () {},
                    icon: const Icon(Icons.share_outlined, size: 16),
                    label: const Text('Share'),
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size(0, 42),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ReportRow extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color? valueColor;

  const _ReportRow({
    required this.label,
    required this.value,
    required this.icon,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(icon, size: 16, color: AppColors.textTertiary),
          const SizedBox(width: 10),
          Expanded(child: Text(label, style: AppTextStyles.bodyMedium)),
          Text(
            value,
            style: AppTextStyles.labelMedium.copyWith(
              color: valueColor ?? AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}

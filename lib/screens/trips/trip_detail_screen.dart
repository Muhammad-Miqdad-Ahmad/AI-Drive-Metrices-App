import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_text_styles.dart';
import '../../core/services/mock_data_service.dart';
import '../../core/utils/date_formatter.dart';
import '../../models/models.dart';
import '../../widgets/common/score_gauge_widget.dart';
import '../../widgets/common/stat_card_widget.dart';

class TripDetailScreen extends StatelessWidget {
  final String tripId;
  final TripModel? trip;

  const TripDetailScreen({
    super.key,
    required this.tripId,
    this.trip,
  });

  TripModel get _trip {
    if (trip != null) return trip!;
    final all = MockDataService.trips;
    final found = all.where((t) => t.id == tripId);
    return found.isNotEmpty ? found.first : all.first;
  }

  @override
  Widget build(BuildContext context) {
    final t = _trip;
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(DateFormatter.tripDate(t.startTime)),
        backgroundColor: AppColors.surface,
        actions: [
          IconButton(
            icon: const Icon(Icons.share_outlined),
            onPressed: () {},
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _ScoreCard(trip: t),
            const SizedBox(height: 20),
            const Text('Trip Stats', style: AppTextStyles.h3),
            const SizedBox(height: 12),
            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 1.4,
              children: [
                StatCard(
                  label: 'Distance',
                  value: t.distanceKm.toStringAsFixed(1),
                  unit: 'km',
                  icon: Icons.route_rounded,
                ),
                StatCard(
                  label: 'Duration',
                  value: t.durationLabel,
                  icon: Icons.timer_outlined,
                  iconColor: AppColors.accent,
                  iconBg: AppColors.accentLight,
                ),
                StatCard(
                  label: 'Max Speed',
                  value: '${t.maxSpeedKmh.toInt()}',
                  unit: 'km/h',
                  icon: Icons.speed_rounded,
                  iconColor: AppColors.warning,
                  iconBg: AppColors.warningLight,
                ),
                StatCard(
                  label: 'Avg Speed',
                  value: '${t.avgSpeedKmh.toInt()}',
                  unit: 'km/h',
                  icon: Icons.speed_outlined,
                ),
              ],
            ),
            const SizedBox(height: 20),
            _ScoreBreakdown(score: t.score),
            const SizedBox(height: 20),
            if (t.events.isNotEmpty) ...[
              _EventsSection(events: t.events),
              const SizedBox(height: 20),
            ],
            _MapSection(trip: t),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}

class _ScoreCard extends StatelessWidget {
  final TripModel trip;
  const _ScoreCard({required this.trip});

  @override
  Widget build(BuildContext context) {
    final color = AppColors.scoreColor(trip.score.overall);
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
        boxShadow: AppColors.cardShadow,
      ),
      child: Row(
        children: [
          ScoreGaugeWidget(score: trip.score.overall, size: 120),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Overall Score', style: AppTextStyles.labelMedium),
                const SizedBox(height: 4),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.scoreColorLight(trip.score.overall),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    'Grade ${trip.score.grade}',
                    style: AppTextStyles.labelLarge.copyWith(color: color),
                  ),
                ),
                const SizedBox(height: 12),
                _ScoreRow(label: 'Braking', value: trip.score.braking),
                _ScoreRow(label: 'Cornering', value: trip.score.cornering),
                _ScoreRow(label: 'Speeding', value: trip.score.speeding),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ScoreRow extends StatelessWidget {
  final String label;
  final double value;
  const _ScoreRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          Expanded(child: Text(label, style: AppTextStyles.bodySmall)),
          Text(
            value.toInt().toString(),
            style: AppTextStyles.labelSmall.copyWith(
              color: AppColors.scoreColor(value),
            ),
          ),
        ],
      ),
    );
  }
}

class _ScoreBreakdown extends StatelessWidget {
  final DriverScoreModel score;
  const _ScoreBreakdown({required this.score});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
        boxShadow: AppColors.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Score Breakdown', style: AppTextStyles.h3),
          const SizedBox(height: 16),
          SizedBox(
            height: 180,
            child: RadarChart(
              RadarChartData(
                radarShape: RadarShape.polygon,
                tickCount: 4,
                ticksTextStyle: AppTextStyles.overline,
                dataSets: [
                  RadarDataSet(
                    fillColor: AppColors.primary.withValues(alpha: 0.15),
                    borderColor: AppColors.primary,
                    borderWidth: 2,
                    entryRadius: 4,
                    dataEntries: [
                      RadarEntry(value: score.braking),
                      RadarEntry(value: score.cornering),
                      RadarEntry(value: score.speeding),
                      RadarEntry(value: score.smoothness),
                    ],
                  ),
                ],
                getTitle: (index, angle) {
                  const titles = ['Braking', 'Cornering', 'Speeding', 'Smooth'];
                  return RadarChartTitle(
                    text: titles[index],
                    angle: angle,
                    positionPercentageOffset: 0.1,
                  );
                },
                radarBackgroundColor: Colors.transparent,
                borderData: FlBorderData(show: false),
                gridBorderData:
                    const BorderSide(color: AppColors.border, width: 1),
                radarBorderData:
                    const BorderSide(color: AppColors.border, width: 1),
                tickBorderData:
                    const BorderSide(color: AppColors.border, width: 1),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _EventsSection extends StatelessWidget {
  final List<TripEvent> events;
  const _EventsSection({required this.events});

  IconData _iconForType(TripEventType type) {
    switch (type) {
      case TripEventType.harshBraking:
        return Icons.car_crash_rounded;
      case TripEventType.sharpTurn:
        return Icons.turn_right_rounded;
      case TripEventType.speeding:
        return Icons.speed_rounded;
      case TripEventType.collision:
        return Icons.warning_rounded;
      case TripEventType.hardAccel:
        return Icons.trending_up_rounded;
    }
  }

  Color _colorForType(TripEventType type) {
    switch (type) {
      case TripEventType.sharpTurn:
      case TripEventType.hardAccel:
        return AppColors.warning;
      default:
        return AppColors.danger;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
        boxShadow: AppColors.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text('Events', style: AppTextStyles.h3),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.dangerLight,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '${events.length}',
                  style: AppTextStyles.labelSmall
                      .copyWith(color: AppColors.danger),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ...events.asMap().entries.map((entry) {
            final i = entry.key;
            final event = entry.value;
            final color = _colorForType(event.type);
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Column(
                  children: [
                    Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.12),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(_iconForType(event.type),
                          size: 16, color: color),
                    ),
                    if (i < events.length - 1)
                      Container(
                          width: 1.5, height: 28, color: AppColors.border),
                  ],
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(event.label, style: AppTextStyles.labelLarge),
                        const SizedBox(height: 2),
                        Text(DateFormatter.time(event.timestamp),
                            style: AppTextStyles.bodySmall),
                        if (event.value != null) ...[
                          const SizedBox(height: 2),
                          Text(
                            event.type == TripEventType.speeding
                                ? '${event.value!.toInt()} km/h'
                                : '${event.value!.toStringAsFixed(2)}g force',
                            style:
                                AppTextStyles.monoSmall.copyWith(color: color),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ],
            );
          }),
        ],
      ),
    );
  }
}

class _MapSection extends StatelessWidget {
  final TripModel trip;
  const _MapSection({required this.trip});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
        boxShadow: AppColors.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Route', style: AppTextStyles.h3),
          const SizedBox(height: 12),
          Container(
            height: 180,
            decoration: BoxDecoration(
              color: AppColors.surfaceVariant,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.map_outlined,
                      size: 40, color: AppColors.textTertiary),
                  const SizedBox(height: 8),
                  const Text('Google Maps integration',
                      style: AppTextStyles.bodySmall),
                  Text('${trip.route.length} GPS points recorded',
                      style: AppTextStyles.caption),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              const Icon(Icons.location_on_outlined,
                  size: 14, color: AppColors.textTertiary),
              const SizedBox(width: 4),
              Text(
                'Start: ${trip.route.first.latitude.toStringAsFixed(4)}, '
                '${trip.route.first.longitude.toStringAsFixed(4)}',
                style: AppTextStyles.monoSmall,
              ),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              const Icon(Icons.flag_outlined,
                  size: 14, color: AppColors.textTertiary),
              const SizedBox(width: 4),
              Text(
                'End: ${trip.route.last.latitude.toStringAsFixed(4)}, '
                '${trip.route.last.longitude.toStringAsFixed(4)}',
                style: AppTextStyles.monoSmall,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

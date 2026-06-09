import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
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
        padding: EdgeInsets.all(20.r),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _ScoreCard(trip: t),
            SizedBox(height: 20.h),
            Text('Trip Stats', style: AppTextStyles.h3),
            SizedBox(height: 12.h),
            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisSpacing: 12.w,
              mainAxisSpacing: 12.h,
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
            SizedBox(height: 20.h),
            _ScoreBreakdown(score: t.score),
            SizedBox(height: 20.h),
            if (t.events.isNotEmpty) ...[
              _EventsSection(events: t.events),
              SizedBox(height: 20.h),
            ],
            _MapSection(trip: t),
            SizedBox(height: 32.h),
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
      padding: EdgeInsets.all(20.r),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20.r),
        border: Border.all(color: AppColors.border),
        boxShadow: AppColors.cardShadow,
      ),
      child: Row(
        children: [
          ScoreGaugeWidget(score: trip.score.overall, size: 120),
          SizedBox(width: 20.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Overall Score', style: AppTextStyles.labelMedium),
                SizedBox(height: 4.h),
                Container(
                  padding:
                      EdgeInsets.symmetric(horizontal: 10.w, vertical: 4.h),
                  decoration: BoxDecoration(
                    color: AppColors.scoreColorLight(trip.score.overall),
                    borderRadius: BorderRadius.circular(8.r),
                  ),
                  child: Text(
                    'Grade ${trip.score.grade}',
                    style: AppTextStyles.labelLarge.copyWith(color: color),
                  ),
                ),
                SizedBox(height: 12.h),
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
      padding: EdgeInsets.only(bottom: 4.h),
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
      padding: EdgeInsets.all(20.r),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(color: AppColors.border),
        boxShadow: AppColors.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Score Breakdown', style: AppTextStyles.h3),
          SizedBox(height: 16.h),
          SizedBox(
            height: 180.h,
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
      padding: EdgeInsets.all(20.r),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(color: AppColors.border),
        boxShadow: AppColors.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text('Events', style: AppTextStyles.h3),
              SizedBox(width: 8.w),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 2.h),
                decoration: BoxDecoration(
                  color: AppColors.dangerLight,
                  borderRadius: BorderRadius.circular(8.r),
                ),
                child: Text(
                  '${events.length}',
                  style: AppTextStyles.labelSmall
                      .copyWith(color: AppColors.danger),
                ),
              ),
            ],
          ),
          SizedBox(height: 16.h),
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
                      width: 32.r,
                      height: 32.r,
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.12),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(_iconForType(event.type),
                          size: 16.r, color: color),
                    ),
                    if (i < events.length - 1)
                      Container(
                          width: 1.5, height: 28.h, color: AppColors.border),
                  ],
                ),
                SizedBox(width: 12.w),
                Expanded(
                  child: Padding(
                    padding: EdgeInsets.only(bottom: 20.h),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(event.label, style: AppTextStyles.labelLarge),
                        SizedBox(height: 2.h),
                        Text(DateFormatter.time(event.timestamp),
                            style: AppTextStyles.bodySmall),
                        if (event.value != null) ...[
                          SizedBox(height: 2.h),
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
      padding: EdgeInsets.all(20.r),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(color: AppColors.border),
        boxShadow: AppColors.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Route', style: AppTextStyles.h3),
          SizedBox(height: 12.h),
          Container(
            height: 180.h,
            decoration: BoxDecoration(
              color: AppColors.surfaceVariant,
              borderRadius: BorderRadius.circular(12.r),
            ),
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.map_outlined,
                      size: 40.r, color: AppColors.textTertiary),
                  SizedBox(height: 8.h),
                  Text('Google Maps integration',
                      style: AppTextStyles.bodySmall),
                  Text('${trip.route.length} GPS points recorded',
                      style: AppTextStyles.caption),
                ],
              ),
            ),
          ),
          SizedBox(height: 12.h),
          Row(
            children: [
              Icon(Icons.location_on_outlined,
                  size: 14.r, color: AppColors.textTertiary),
              SizedBox(width: 4.w),
              Text(
                'Start: ${trip.route.first.latitude.toStringAsFixed(4)}, '
                '${trip.route.first.longitude.toStringAsFixed(4)}',
                style: AppTextStyles.monoSmall,
              ),
            ],
          ),
          SizedBox(height: 4.h),
          Row(
            children: [
              Icon(Icons.flag_outlined,
                  size: 14.r, color: AppColors.textTertiary),
              SizedBox(width: 4.w),
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

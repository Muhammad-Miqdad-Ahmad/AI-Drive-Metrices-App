import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_text_styles.dart';
import '../../core/services/supabase_service.dart';
import '../../core/storage/local_storage_service.dart';
import '../../core/utils/date_formatter.dart';
import '../../models/models.dart';
import '../../widgets/common/stat_card_widget.dart';

class TripDetailScreen extends StatefulWidget {
  final String tripId;
  final TripModel? trip;

  const TripDetailScreen({
    super.key,
    required this.tripId,
    this.trip,
  });

  @override
  State<TripDetailScreen> createState() => _TripDetailScreenState();
}

class _TripDetailScreenState extends State<TripDetailScreen>
    with TickerProviderStateMixin {
  TripModel? _trip;
  bool _loadingDetail = false;
  String? _detailError;
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _trip = widget.trip;
    _tabController = TabController(length: 3, vsync: this);
    _fetchDetail();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _fetchDetail() async {
    setState(() {
      _loadingDetail = true;
      _detailError = null;
    });
    try {
      final token = await LocalStorageService.getDeviceToken();
      if (token == null) return;

      final svc = SupabaseService(deviceToken: token);
      final full = await svc.getTripDetail(widget.tripId);
      if (mounted && full != null) {
        setState(() => _trip = full);
      }
    } catch (e) {
      if (mounted) setState(() => _detailError = e.toString());
    } finally {
      if (mounted) setState(() => _loadingDetail = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_trip == null) {
      return Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(backgroundColor: AppColors.surface),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    final t = _trip!;
    final scoreColor = AppColors.scoreColor(t.score.overall);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        title: Text(DateFormatter.tripDate(t.startTime)),
        actions: [
          if (_loadingDetail)
            const Padding(
              padding: EdgeInsets.all(16),
              child: SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          IconButton(
            icon: const Icon(Icons.share_outlined),
            onPressed: () {},
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          labelColor: AppColors.primary,
          unselectedLabelColor: AppColors.textSecondary,
          indicatorColor: AppColors.primary,
          tabs: const [
            Tab(text: 'Overview'),
            Tab(text: 'Events'),
            Tab(text: 'Route'),
          ],
        ),
      ),
      body: Column(
        children: [
          _TripHeroCard(trip: t),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _OverviewTab(trip: t),
                _EventsTab(trip: t, loadingDetail: _loadingDetail),
                _RouteTab(trip: t),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Hero header card ──────────────────────────────────────────────────────

class _TripHeroCard extends StatelessWidget {
  final TripModel trip;
  const _TripHeroCard({required this.trip});

  @override
  Widget build(BuildContext context) {
    final score = trip.score.overall;
    final scoreColor = AppColors.scoreColor(score);

    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF0A2463), Color(0xFF0057FF)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 14),
      child: Row(
        children: [
          // Circular score
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.15),
              shape: BoxShape.circle,
              border: Border.all(
                  color: scoreColor.withValues(alpha: 0.8), width: 3),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  score.toInt().toString(),
                  style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.white),
                ),
                Text(
                  trip.score.grade,
                  style: TextStyle(
                      fontSize: 11,
                      color: scoreColor,
                      fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  DateFormatter.tripDate(trip.startTime),
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                Text(
                  '${DateFormatter.time(trip.startTime)} · ${trip.durationLabel}',
                  style: const TextStyle(color: Colors.white70, fontSize: 13),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    _HeroChip(
                        icon: Icons.route_rounded,
                        label: '${trip.distanceKm.toStringAsFixed(1)} km'),
                    const SizedBox(width: 8),
                    _HeroChip(
                        icon: Icons.speed_rounded,
                        label: '${trip.maxSpeedKmh.toInt()} km/h'),
                    if (trip.harshEventCount > 0) ...[
                      const SizedBox(width: 8),
                      _HeroChip(
                          icon: Icons.warning_amber_rounded,
                          label: '${trip.harshEventCount} events',
                          danger: true),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _HeroChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool danger;

  const _HeroChip(
      {required this.icon, required this.label, this.danger = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: danger
            ? AppColors.danger.withValues(alpha: 0.25)
            : Colors.white.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: danger
              ? AppColors.danger.withValues(alpha: 0.5)
              : Colors.white.withValues(alpha: 0.25),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon,
              size: 11, color: danger ? AppColors.danger : Colors.white70),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
                fontSize: 11,
                color: danger ? AppColors.danger : Colors.white,
                fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}

// ── Overview tab ──────────────────────────────────────────────────────────

class _OverviewTab extends StatelessWidget {
  final TripModel trip;
  const _OverviewTab({required this.trip});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Stats grid
          const Text('Trip Statistics', style: AppTextStyles.h3),
          const SizedBox(height: 12),
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 1.5,
            children: [
              StatCard(
                label: 'Distance',
                value: trip.distanceKm.toStringAsFixed(1),
                unit: 'km',
                icon: Icons.route_rounded,
              ),
              StatCard(
                label: 'Duration',
                value: trip.durationLabel,
                icon: Icons.timer_outlined,
                iconColor: AppColors.accent,
                iconBg: AppColors.accentLight,
              ),
              StatCard(
                label: 'Max Speed',
                value: '${trip.maxSpeedKmh.toInt()}',
                unit: 'km/h',
                icon: Icons.speed_rounded,
                iconColor: AppColors.warning,
                iconBg: AppColors.warningLight,
              ),
              StatCard(
                label: 'Avg Speed',
                value: '${trip.avgSpeedKmh.toInt()}',
                unit: 'km/h',
                icon: Icons.speed_outlined,
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Score breakdown
          _ScoreBreakdownCard(score: trip.score),
          const SizedBox(height: 20),

          // Driving behavior analysis
          _DrivingAnalysisCard(trip: trip),
          const SizedBox(height: 20),

          // Speed profile if route has speed data
          if (trip.route.any((p) => p.speedKmh != null)) ...[
            _SpeedProfileCard(route: trip.route),
            const SizedBox(height: 20),
          ],

          // Recommendations
          _RecommendationsCard(trip: trip),
          const SizedBox(height: 32),
        ],
      ),
    );
  }
}

// ── Score breakdown card ──────────────────────────────────────────────────

class _ScoreBreakdownCard extends StatelessWidget {
  final DriverScoreModel score;
  const _ScoreBreakdownCard({required this.score});

  @override
  Widget build(BuildContext context) {
    final categories = [
      _ScoreCat('Braking', score.braking, Icons.car_crash_rounded,
          'How smoothly you slow down'),
      _ScoreCat('Cornering', score.cornering, Icons.turn_right_rounded,
          'Lateral forces during turns'),
      _ScoreCat('Acceleration', score.acceleration, Icons.trending_up_rounded,
          'Smoothness when speeding up'),
      _ScoreCat('Smoothness', score.smoothness, Icons.waves_rounded,
          'Overall ride consistency'),
    ];

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
              const Text('Score Breakdown', style: AppTextStyles.h3),
              const Spacer(),
              SizedBox(
                height: 70,
                width: 70,
                child: RadarChart(
                  RadarChartData(
                    radarShape: RadarShape.polygon,
                    tickCount: 3,
                    ticksTextStyle:
                        const TextStyle(fontSize: 0, color: Colors.transparent),
                    dataSets: [
                      RadarDataSet(
                        fillColor: AppColors.primary.withValues(alpha: 0.15),
                        borderColor: AppColors.primary,
                        borderWidth: 1.5,
                        entryRadius: 2,
                        dataEntries: [
                          RadarEntry(value: score.braking),
                          RadarEntry(value: score.cornering),
                          RadarEntry(value: score.acceleration),
                          RadarEntry(value: score.smoothness),
                        ],
                      ),
                    ],
                    getTitle: (_, __) => const RadarChartTitle(text: ''),
                    radarBackgroundColor: Colors.transparent,
                    borderData: FlBorderData(show: false),
                    gridBorderData:
                        const BorderSide(color: AppColors.border, width: 0.5),
                    radarBorderData:
                        const BorderSide(color: AppColors.border, width: 0.5),
                    tickBorderData:
                        const BorderSide(color: AppColors.border, width: 0.5),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ...categories.map((cat) => _ScoreBar(cat: cat)),
        ],
      ),
    );
  }
}

class _ScoreCat {
  final String name;
  final double value;
  final IconData icon;
  final String description;
  _ScoreCat(this.name, this.value, this.icon, this.description);
}

class _ScoreBar extends StatelessWidget {
  final _ScoreCat cat;
  const _ScoreBar({required this.cat});

  @override
  Widget build(BuildContext context) {
    final color = AppColors.scoreColor(cat.value);
    final colorLight = AppColors.scoreColorLight(cat.value);

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: colorLight,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(cat.icon, size: 18, color: color),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(cat.name, style: AppTextStyles.labelMedium),
                    const Spacer(),
                    Text(
                      '${cat.value.toInt()}/100',
                      style: AppTextStyles.labelSmall.copyWith(color: color),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: cat.value / 100,
                    minHeight: 6,
                    backgroundColor: AppColors.border,
                    valueColor: AlwaysStoppedAnimation<Color>(color),
                  ),
                ),
                const SizedBox(height: 2),
                Text(cat.description,
                    style: AppTextStyles.overline
                        .copyWith(color: AppColors.textTertiary)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Driving analysis card ─────────────────────────────────────────────────

class _DrivingAnalysisCard extends StatelessWidget {
  final TripModel trip;
  const _DrivingAnalysisCard({required this.trip});

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
          const Row(
            children: [
              Icon(Icons.analytics_outlined,
                  size: 20, color: AppColors.primary),
              SizedBox(width: 8),
              Text('Driving Behaviour', style: AppTextStyles.h3),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              _BehaviourTile(
                icon: Icons.car_crash_rounded,
                color: AppColors.danger,
                bgColor: AppColors.dangerLight,
                count: trip.harshBrakingCount,
                label: 'Harsh\nBraking',
              ),
              _BehaviourTile(
                icon: Icons.turn_right_rounded,
                color: AppColors.warning,
                bgColor: AppColors.warningLight,
                count: trip.sharpTurnCount,
                label: 'Sharp\nTurns',
              ),
              _BehaviourTile(
                icon: Icons.trending_up_rounded,
                color: AppColors.accent,
                bgColor: AppColors.accentLight,
                count: trip.hardAccelCount,
                label: 'Hard\nAccel',
              ),
              _BehaviourTile(
                icon: Icons.check_circle_outline_rounded,
                color: AppColors.success,
                bgColor: AppColors.successLight,
                count: trip.events
                    .where((e) => e.type == TripEventType.normalDriving)
                    .length,
                label: 'Normal\nDriving',
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Insight text
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.primarySurface,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.lightbulb_outline_rounded,
                    size: 16, color: AppColors.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _generateInsight(trip),
                    style: AppTextStyles.bodySmall
                        .copyWith(color: AppColors.primary),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _generateInsight(TripModel trip) {
    if (trip.score.overall >= 90) {
      return 'Excellent drive! Your smooth and controlled style is very fuel efficient and reduces vehicle wear.';
    } else if (trip.harshBrakingCount > 2) {
      return 'You braked harshly ${trip.harshBrakingCount} times. Try to anticipate stops earlier for a smoother ride.';
    } else if (trip.sharpTurnCount > 3) {
      return 'You took ${trip.sharpTurnCount} sharp turns. Slowing down before corners improves safety and tyre life.';
    } else if (trip.score.overall >= 70) {
      return 'Good trip overall! Minor improvements in braking smoothness could push your score higher.';
    } else {
      return 'Focus on smoother braking and steady acceleration. Consistency over time greatly improves your score.';
    }
  }
}

class _BehaviourTile extends StatelessWidget {
  final IconData icon;
  final Color color;
  final Color bgColor;
  final int count;
  final String label;

  const _BehaviourTile({
    required this.icon,
    required this.color,
    required this.bgColor,
    required this.count,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: bgColor,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, size: 20, color: color),
          ),
          const SizedBox(height: 6),
          Text(
            count.toString(),
            style: TextStyle(
                fontSize: 18, fontWeight: FontWeight.bold, color: color),
          ),
          Text(
            label,
            style:
                AppTextStyles.overline.copyWith(color: AppColors.textSecondary),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

// ── Speed profile chart ───────────────────────────────────────────────────

class _SpeedProfileCard extends StatelessWidget {
  final List<LatLngPoint> route;
  const _SpeedProfileCard({required this.route});

  @override
  Widget build(BuildContext context) {
    final speedPoints = route.where((p) => p.speedKmh != null).toList();

    if (speedPoints.isEmpty) return const SizedBox.shrink();

    final spots = speedPoints.asMap().entries.map((e) {
      return FlSpot(e.key.toDouble(), e.value.speedKmh!);
    }).toList();

    final maxSpeed = speedPoints.map((p) => p.speedKmh!).reduce(math.max);

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
          const Row(
            children: [
              Icon(Icons.show_chart_rounded,
                  size: 20, color: AppColors.primary),
              SizedBox(width: 8),
              Text('Speed Profile', style: AppTextStyles.h3),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Max: ${maxSpeed.toInt()} km/h',
            style: AppTextStyles.bodySmall,
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 140,
            child: LineChart(
              LineChartData(
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  getDrawingHorizontalLine: (v) => FlLine(
                    color: AppColors.border,
                    strokeWidth: 0.5,
                  ),
                ),
                titlesData: FlTitlesData(
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 32,
                      getTitlesWidget: (v, _) => Text(
                        '${v.toInt()}',
                        style: AppTextStyles.overline,
                      ),
                    ),
                  ),
                  bottomTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false)),
                  topTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false)),
                ),
                borderData: FlBorderData(show: false),
                lineBarsData: [
                  LineChartBarData(
                    spots: spots,
                    isCurved: true,
                    color: AppColors.primary,
                    barWidth: 2,
                    dotData: const FlDotData(show: false),
                    belowBarData: BarAreaData(
                      show: true,
                      color: AppColors.primary.withValues(alpha: 0.1),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Recommendations card ──────────────────────────────────────────────────

class _RecommendationsCard extends StatelessWidget {
  final TripModel trip;
  const _RecommendationsCard({required this.trip});

  List<_Tip> _getTips() {
    final tips = <_Tip>[];
    if (trip.score.braking < 70) {
      tips.add(_Tip(
        icon: Icons.car_crash_rounded,
        color: AppColors.danger,
        title: 'Improve Braking',
        body:
            'Anticipate stops 3-4 seconds earlier. Gradual pressure reduces brake wear and improves your score.',
      ));
    }
    if (trip.score.cornering < 70) {
      tips.add(_Tip(
        icon: Icons.turn_right_rounded,
        color: AppColors.warning,
        title: 'Smoother Cornering',
        body:
            'Reduce speed before corners, not during. Enter slow, exit fast for better control.',
      ));
    }
    if (trip.score.acceleration < 70) {
      tips.add(_Tip(
        icon: Icons.trending_up_rounded,
        color: AppColors.accent,
        title: 'Steady Acceleration',
        body:
            'Avoid flooring the pedal. Gradual acceleration is more fuel-efficient and comfortable.',
      ));
    }
    if (trip.score.overall >= 85) {
      tips.add(_Tip(
        icon: Icons.emoji_events_rounded,
        color: AppColors.success,
        title: 'Great Drive!',
        body:
            'You scored ${trip.score.overall.toInt()}/100. Keep this consistency to maintain a top-tier rating.',
      ));
    }
    return tips;
  }

  @override
  Widget build(BuildContext context) {
    final tips = _getTips();
    if (tips.isEmpty) return const SizedBox.shrink();

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
          const Row(
            children: [
              Icon(Icons.tips_and_updates_outlined,
                  size: 20, color: AppColors.primary),
              SizedBox(width: 8),
              Text('Recommendations', style: AppTextStyles.h3),
            ],
          ),
          const SizedBox(height: 16),
          ...tips.map((t) => _TipItem(tip: t)),
        ],
      ),
    );
  }
}

class _Tip {
  final IconData icon;
  final Color color;
  final String title;
  final String body;
  _Tip(
      {required this.icon,
      required this.color,
      required this.title,
      required this.body});
}

class _TipItem extends StatelessWidget {
  final _Tip tip;
  const _TipItem({required this.tip});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: tip.color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(tip.icon, size: 18, color: tip.color),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(tip.title, style: AppTextStyles.labelMedium),
                const SizedBox(height: 2),
                Text(tip.body,
                    style: AppTextStyles.bodySmall
                        .copyWith(color: AppColors.textSecondary)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Events tab ────────────────────────────────────────────────────────────

class _EventsTab extends StatelessWidget {
  final TripModel trip;
  final bool loadingDetail;

  const _EventsTab({required this.trip, required this.loadingDetail});

  @override
  Widget build(BuildContext context) {
    if (loadingDetail && trip.events.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    final harsh = trip.events.where((e) => e.type.isHarsh).toList();
    final all = List<TripEvent>.from(trip.events);

    if (all.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.check_circle_outline_rounded,
                size: 48, color: AppColors.success),
            const SizedBox(height: 12),
            const Text('No events recorded', style: AppTextStyles.h3),
            const SizedBox(height: 8),
            Text(
              loadingDetail
                  ? 'Loading events...'
                  : 'Clean drive! No harsh events detected.',
              style: AppTextStyles.bodyMedium,
            ),
          ],
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Summary chips
          Row(
            children: [
              _EventChip(
                  icon: Icons.car_crash_rounded,
                  count: trip.harshBrakingCount,
                  label: 'Braking',
                  color: AppColors.danger),
              const SizedBox(width: 8),
              _EventChip(
                  icon: Icons.turn_right_rounded,
                  count: trip.sharpTurnCount,
                  label: 'Turns',
                  color: AppColors.warning),
              const SizedBox(width: 8),
              _EventChip(
                  icon: Icons.trending_up_rounded,
                  count: trip.hardAccelCount,
                  label: 'Accel',
                  color: AppColors.accent),
            ],
          ),
          const SizedBox(height: 20),
          if (harsh.isNotEmpty) ...[
            Text(
              'Harsh Events (${harsh.length})',
              style: AppTextStyles.h3,
            ),
            const SizedBox(height: 12),
            _EventTimeline(events: harsh),
          ],
        ],
      ),
    );
  }
}

class _EventChip extends StatelessWidget {
  final IconData icon;
  final int count;
  final String label;
  final Color color;

  const _EventChip(
      {required this.icon,
      required this.count,
      required this.label,
      required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 6),
          Text(
            '$count $label',
            style: TextStyle(
                fontSize: 12, fontWeight: FontWeight.bold, color: color),
          ),
        ],
      ),
    );
  }
}

class _EventTimeline extends StatelessWidget {
  final List<TripEvent> events;
  const _EventTimeline({required this.events});

  IconData _iconFor(TripEventType type) {
    switch (type) {
      case TripEventType.harshBraking:
        return Icons.car_crash_rounded;
      case TripEventType.rightTurn:
        return Icons.turn_right_rounded;
      case TripEventType.leftTurn:
        return Icons.turn_left_rounded;
      case TripEventType.hardAccel:
        return Icons.trending_up_rounded;
      default:
        return Icons.check_circle_outline;
    }
  }

  Color _colorFor(TripEventType type) {
    switch (type) {
      case TripEventType.harshBraking:
        return AppColors.danger;
      case TripEventType.leftTurn:
      case TripEventType.rightTurn:
        return AppColors.warning;
      case TripEventType.hardAccel:
        return AppColors.accent;
      default:
        return AppColors.success;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
        boxShadow: AppColors.cardShadow,
      ),
      child: Column(
        children: events.asMap().entries.map((entry) {
          final i = entry.key;
          final event = entry.value;
          final color = _colorFor(event.type);
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Column(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                      border: Border.all(color: color.withValues(alpha: 0.3)),
                    ),
                    child: Icon(_iconFor(event.type), size: 16, color: color),
                  ),
                  if (i < events.length - 1)
                    Container(width: 1.5, height: 32, color: AppColors.border),
                ],
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 20),
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: color.withValues(alpha: 0.2)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(event.label, style: AppTextStyles.labelLarge),
                            const Spacer(),
                            if (event.speedKmh != null)
                              Text(
                                '${event.speedKmh!.toInt()} km/h',
                                style: AppTextStyles.labelSmall
                                    .copyWith(color: color),
                              ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          DateFormatter.time(event.timestamp),
                          style: AppTextStyles.bodySmall,
                        ),
                        if (event.confidence > 0) ...[
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              Text('Confidence: ',
                                  style: AppTextStyles.overline),
                              SizedBox(
                                width: 60,
                                height: 4,
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(2),
                                  child: LinearProgressIndicator(
                                    value: event.confidence,
                                    backgroundColor: AppColors.border,
                                    valueColor:
                                        AlwaysStoppedAnimation<Color>(color),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                '${(event.confidence * 100).toInt()}%',
                                style: AppTextStyles.overline
                                    .copyWith(color: color),
                              ),
                            ],
                          ),
                        ],
                        if (event.accelX != null) ...[
                          const SizedBox(height: 6),
                          Wrap(
                            spacing: 8,
                            children: [
                              _AccelBadge(
                                  label: 'X',
                                  value: event.accelX!,
                                  color: color),
                              _AccelBadge(
                                  label: 'Y',
                                  value: event.accelY ?? 0,
                                  color: color),
                              _AccelBadge(
                                  label: 'Z',
                                  value: event.accelZ ?? 0,
                                  color: color),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ],
          );
        }).toList(),
      ),
    );
  }
}

class _AccelBadge extends StatelessWidget {
  final String label;
  final double value;
  final Color color;

  const _AccelBadge(
      {required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        '$label: ${value.toStringAsFixed(2)}g',
        style:
            TextStyle(fontSize: 10, color: color, fontWeight: FontWeight.w600),
      ),
    );
  }
}

// ── Route tab (OpenStreetMap via flutter_map) ─────────────────────────────

class _RouteTab extends StatelessWidget {
  final TripModel trip;
  const _RouteTab({required this.trip});

  @override
  Widget build(BuildContext context) {
    final hasRoute = trip.route.length >= 2;

    if (!hasRoute) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.map_outlined,
                size: 48, color: AppColors.textTertiary),
            const SizedBox(height: 12),
            const Text('No route data', style: AppTextStyles.h3),
            const SizedBox(height: 8),
            Text(
              'GPS route will appear here once recorded.',
              style: AppTextStyles.bodyMedium,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    final points =
        trip.route.map((p) => LatLng(p.latitude, p.longitude)).toList();

    // Compute bounds
    double minLat = points.first.latitude;
    double maxLat = points.first.latitude;
    double minLng = points.first.longitude;
    double maxLng = points.first.longitude;
    for (final p in points) {
      if (p.latitude < minLat) minLat = p.latitude;
      if (p.latitude > maxLat) maxLat = p.latitude;
      if (p.longitude < minLng) minLng = p.longitude;
      if (p.longitude > maxLng) maxLng = p.longitude;
    }

    final centerLat = (minLat + maxLat) / 2;
    final centerLng = (minLng + maxLng) / 2;

    // Harsh event markers
    final harshEvents = trip.events.where((e) => e.type.isHarsh).toList();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Map
          Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.border),
              boxShadow: AppColors.cardShadow,
            ),
            clipBehavior: Clip.antiAlias,
            child: SizedBox(
              height: 320,
              child: FlutterMap(
                options: MapOptions(
                  initialCenter: LatLng(centerLat, centerLng),
                  initialZoom: 14,
                  interactionOptions: const InteractionOptions(
                    flags: InteractiveFlag.all,
                  ),
                ),
                children: [
                  TileLayer(
                    urlTemplate:
                        'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                    userAgentPackageName: 'com.drivemetricsai.app',
                  ),
                  // Route polyline
                  PolylineLayer(
                    polylines: [
                      Polyline(
                        points: points,
                        strokeWidth: 4,
                        color: AppColors.primary,
                      ),
                    ],
                  ),
                  // Event markers
                  MarkerLayer(
                    markers: [
                      // Start marker
                      Marker(
                        point: points.first,
                        width: 32,
                        height: 32,
                        child: Container(
                          decoration: BoxDecoration(
                            color: AppColors.success,
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 2),
                            boxShadow: [
                              BoxShadow(
                                  color:
                                      AppColors.success.withValues(alpha: 0.4),
                                  blurRadius: 8)
                            ],
                          ),
                          child: const Icon(Icons.play_arrow_rounded,
                              size: 16, color: Colors.white),
                        ),
                      ),
                      // End marker
                      Marker(
                        point: points.last,
                        width: 32,
                        height: 32,
                        child: Container(
                          decoration: BoxDecoration(
                            color: AppColors.danger,
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 2),
                            boxShadow: [
                              BoxShadow(
                                  color:
                                      AppColors.danger.withValues(alpha: 0.4),
                                  blurRadius: 8)
                            ],
                          ),
                          child: const Icon(Icons.stop_rounded,
                              size: 16, color: Colors.white),
                        ),
                      ),
                      // Harsh event markers
                      ...harshEvents.map((e) => Marker(
                            point: LatLng(e.latitude, e.longitude),
                            width: 24,
                            height: 24,
                            child: Container(
                              decoration: BoxDecoration(
                                color: AppColors.warning,
                                shape: BoxShape.circle,
                                border:
                                    Border.all(color: Colors.white, width: 1.5),
                              ),
                              child: const Icon(Icons.warning_amber_rounded,
                                  size: 12, color: Colors.white),
                            ),
                          )),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Legend
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _LegendItem(color: AppColors.success, label: 'Start'),
              const SizedBox(width: 20),
              _LegendItem(color: AppColors.danger, label: 'End'),
              const SizedBox(width: 20),
              _LegendItem(color: AppColors.warning, label: 'Harsh Event'),
              const SizedBox(width: 20),
              _LegendLine(color: AppColors.primary, label: 'Route'),
            ],
          ),
          const SizedBox(height: 16),

          // GPS summary
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.border),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    const Icon(Icons.location_on_outlined,
                        size: 14, color: AppColors.success),
                    const SizedBox(width: 6),
                    Text('Start',
                        style: AppTextStyles.labelSmall
                            .copyWith(color: AppColors.success)),
                    const Spacer(),
                    Text(
                      '${trip.route.first.latitude.toStringAsFixed(5)}, '
                      '${trip.route.first.longitude.toStringAsFixed(5)}',
                      style: AppTextStyles.monoSmall,
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Icon(Icons.flag_outlined,
                        size: 14, color: AppColors.danger),
                    const SizedBox(width: 6),
                    Text('End',
                        style: AppTextStyles.labelSmall
                            .copyWith(color: AppColors.danger)),
                    const Spacer(),
                    Text(
                      '${trip.route.last.latitude.toStringAsFixed(5)}, '
                      '${trip.route.last.longitude.toStringAsFixed(5)}',
                      style: AppTextStyles.monoSmall,
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Icon(Icons.pin_drop_outlined,
                        size: 14, color: AppColors.textTertiary),
                    const SizedBox(width: 6),
                    Text('GPS Points', style: AppTextStyles.labelSmall),
                    const Spacer(),
                    Text('${trip.route.length}',
                        style: AppTextStyles.monoSmall),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }
}

class _LegendItem extends StatelessWidget {
  final Color color;
  final String label;
  const _LegendItem({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 4),
        Text(label, style: AppTextStyles.overline),
      ],
    );
  }
}

class _LegendLine extends StatelessWidget {
  final Color color;
  final String label;
  const _LegendLine({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(width: 16, height: 3, color: color),
        const SizedBox(width: 4),
        Text(label, style: AppTextStyles.overline),
      ],
    );
  }
}

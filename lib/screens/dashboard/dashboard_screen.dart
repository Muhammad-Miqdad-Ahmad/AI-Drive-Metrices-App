import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:go_router/go_router.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_text_styles.dart';
import '../../core/services/mock_data_service.dart';
import '../../widgets/common/score_gauge_widget.dart';
import '../../widgets/common/stat_card_widget.dart';
import '../../widgets/trip/trip_card_widget.dart';
import '../../app_router.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final user = MockDataService.currentUser;
  final trips = MockDataService.trips;
  final weeklyScores = MockDataService.weeklyScores;

  double get avgScore =>
      trips.map((t) => t.score.overall).reduce((a, b) => a + b) / trips.length;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: CustomScrollView(
        slivers: [
          _buildHeader(),
          SliverPadding(
            padding: const EdgeInsets.all(20),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                // Score section
                _buildScoreCard(),
                const SizedBox(height: 20),

                // Quick stats
                SectionHeader(
                  title: 'This Week',
                  action: 'See All',
                  onAction: () => context.go(AppRoutes.trips),
                ),
                const SizedBox(height: 12),
                _buildQuickStats(),
                const SizedBox(height: 20),

                // Weekly chart
                _buildWeeklyChart(),
                const SizedBox(height: 20),

                // Recent trips
                SectionHeader(
                  title: 'Recent Trips',
                  action: 'View All',
                  onAction: () => context.go(AppRoutes.trips),
                ),
                const SizedBox(height: 12),
                ...trips.take(2).map(
                      (trip) => Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: TripCard(
                          trip: trip,
                          onTap: () => context.push(
                            '/trips/${trip.id}',
                            extra: trip,
                          ),
                        ),
                      ),
                    ),
                const SizedBox(height: 20),
              ]),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return SliverAppBar(
      expandedHeight: 140,
      floating: false,
      pinned: true,
      backgroundColor: AppColors.primary,
      flexibleSpace: FlexibleSpaceBar(
        background: Container(
          decoration: const BoxDecoration(
            gradient: AppColors.dashboardHeaderGradient,
          ),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Good Morning,',
                          style: AppTextStyles.bodyMedium.copyWith(
                              color: Colors.white.withValues(alpha: 0.7)),
                        ),
                        Text(
                          user.fullName.split(' ').first,
                          style: AppTextStyles.h2.copyWith(color: Colors.white),
                        ),
                        const SizedBox(height: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: 6,
                                height: 6,
                                decoration: const BoxDecoration(
                                  color: AppColors.accent,
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                'Device Connected',
                                style: AppTextStyles.labelSmall
                                    .copyWith(color: Colors.white),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Notification bell
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        const Icon(Icons.notifications_outlined,
                            color: Colors.white, size: 20),
                        Positioned(
                          top: 8,
                          right: 8,
                          child: Container(
                            width: 8,
                            height: 8,
                            decoration: const BoxDecoration(
                              color: AppColors.accent,
                              shape: BoxShape.circle,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        title: Padding(
          padding: const EdgeInsets.only(left: 4),
          child: Text(
            'Drive Metrics AI',
            style: AppTextStyles.h4.copyWith(color: Colors.white),
          ),
        ),
        titlePadding: const EdgeInsets.only(left: 20, bottom: 16),
        collapseMode: CollapseMode.parallax,
      ),
      actions: [
        Padding(
          padding: const EdgeInsets.only(right: 12),
          child: IconButton(
            icon: const Icon(Icons.bluetooth_rounded,
                color: Colors.white, size: 22),
            onPressed: () => context.push(AppRoutes.devicePairing),
          ),
        ),
      ],
    );
  }

  Widget _buildScoreCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: AppColors.primaryGradient,
        borderRadius: BorderRadius.circular(20),
        boxShadow: AppColors.primaryShadow,
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Safety Score',
                  style: AppTextStyles.labelMedium
                      .copyWith(color: Colors.white.withValues(alpha: 0.8)),
                ),
                const SizedBox(height: 6),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      avgScore.toInt().toString(),
                      style:
                          AppTextStyles.display1.copyWith(color: Colors.white),
                    ),
                    Padding(
                      padding: const EdgeInsets.only(bottom: 10, left: 4),
                      child: Text(
                        '/ 100',
                        style: AppTextStyles.bodyMedium.copyWith(
                            color: Colors.white.withValues(alpha: 0.6)),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.accent.withValues(alpha: 0.25),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '↑ 3 pts from last week',
                    style: AppTextStyles.labelSmall
                        .copyWith(color: AppColors.accent),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  '${trips.length} trips recorded',
                  style: AppTextStyles.bodySmall
                      .copyWith(color: Colors.white.withValues(alpha: 0.6)),
                ),
              ],
            ),
          ),
          ScoreGaugeWidget(
            score: avgScore,
            size: 130,
            showLabel: false,
          ),
        ],
      ),
    );
  }

  Widget _buildQuickStats() {
    final totalKm = trips.fold(0.0, (s, t) => s + t.distanceKm);
    final totalEvents = trips.fold(0, (s, t) => s + t.events.length);

    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      childAspectRatio: 1.35,
      children: [
        StatCard(
          label: 'Total Distance',
          value: totalKm.toStringAsFixed(0),
          unit: 'km',
          icon: Icons.route_rounded,
        ),
        StatCard(
          label: 'Total Trips',
          value: '${trips.length}',
          icon: Icons.directions_car_rounded,
          iconColor: AppColors.accent,
          iconBg: AppColors.accentLight,
        ),
        StatCard(
          label: 'Events Detected',
          value: '$totalEvents',
          icon: Icons.warning_amber_rounded,
          iconColor: AppColors.warning,
          iconBg: AppColors.warningLight,
        ),
        StatCard(
          label: 'Best Score',
          value: trips
              .map((t) => t.score.overall.toInt())
              .reduce((a, b) => a > b ? a : b)
              .toString(),
          icon: Icons.emoji_events_rounded,
          iconColor: AppColors.success,
          iconBg: AppColors.successLight,
        ),
      ],
    );
  }

  Widget _buildWeeklyChart() {
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
          const Text('Weekly Score Trend', style: AppTextStyles.h3),
          const SizedBox(height: 4),
          const Text('Last 7 days', style: AppTextStyles.bodySmall),
          const SizedBox(height: 20),
          SizedBox(
            height: 140,
            child: BarChart(
              BarChartData(
                alignment: BarChartAlignment.spaceAround,
                maxY: 100,
                minY: 0,
                barTouchData: BarTouchData(enabled: false),
                titlesData: FlTitlesData(
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (value, meta) {
                        final idx = value.toInt();
                        if (idx < 0 || idx >= weeklyScores.length) {
                          return const SizedBox.shrink();
                        }
                        return Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Text(
                            weeklyScores[idx]['day'] as String,
                            style: AppTextStyles.overline,
                          ),
                        );
                      },
                    ),
                  ),
                  leftTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false)),
                  topTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false)),
                ),
                gridData: const FlGridData(show: false),
                borderData: FlBorderData(show: false),
                barGroups: weeklyScores.asMap().entries.map((entry) {
                  final idx = entry.key;
                  final score = entry.value['score'] as double;
                  final isToday = idx == weeklyScores.length - 1;
                  return BarChartGroupData(
                    x: idx,
                    barRods: [
                      BarChartRodData(
                        toY: score,
                        width: 28,
                        borderRadius: BorderRadius.circular(6),
                        gradient: isToday
                            ? AppColors.primaryGradient
                            : LinearGradient(
                                colors: [
                                  AppColors.scoreColor(score)
                                      .withValues(alpha: 0.4),
                                  AppColors.scoreColor(score)
                                      .withValues(alpha: 0.7),
                                ],
                                begin: Alignment.bottomCenter,
                                end: Alignment.topCenter,
                              ),
                      ),
                    ],
                  );
                }).toList(),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

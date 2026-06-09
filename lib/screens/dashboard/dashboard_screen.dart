import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
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
            padding: EdgeInsets.all(20.r),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                // Score section
                _buildScoreCard(),
                SizedBox(height: 20.h),

                // Quick stats
                SectionHeader(
                  title: 'This Week',
                  action: 'See All',
                  onAction: () => context.go(AppRoutes.trips),
                ),
                SizedBox(height: 12.h),
                _buildQuickStats(),
                SizedBox(height: 20.h),

                // Weekly chart
                _buildWeeklyChart(),
                SizedBox(height: 20.h),

                // Recent trips
                SectionHeader(
                  title: 'Recent Trips',
                  action: 'View All',
                  onAction: () => context.go(AppRoutes.trips),
                ),
                SizedBox(height: 12.h),
                ...trips.take(2).map(
                      (trip) => Padding(
                        padding: EdgeInsets.only(bottom: 12.h),
                        child: TripCard(
                          trip: trip,
                          onTap: () => context.push(
                            '/trips/${trip.id}',
                            extra: trip,
                          ),
                        ),
                      ),
                    ),
                SizedBox(height: 20.h),
              ]),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return SliverAppBar(
      expandedHeight: 140.h,
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
              padding: EdgeInsets.fromLTRB(20.w, 16.h, 20.w, 0),
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
                        SizedBox(height: 4.h),
                        Container(
                          padding: EdgeInsets.symmetric(
                              horizontal: 10.w, vertical: 4.h),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(20.r),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: 6.r,
                                height: 6.r,
                                decoration: const BoxDecoration(
                                  color: AppColors.accent,
                                  shape: BoxShape.circle,
                                ),
                              ),
                              SizedBox(width: 6.w),
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
                    width: 40.r,
                    height: 40.r,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12.r),
                    ),
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        Icon(Icons.notifications_outlined,
                            color: Colors.white, size: 20.r),
                        Positioned(
                          top: 8,
                          right: 8,
                          child: Container(
                            width: 8.r,
                            height: 8.r,
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
          padding: EdgeInsets.only(left: 4.w),
          child: Text(
            'Drive Metrics AI',
            style: AppTextStyles.h4.copyWith(color: Colors.white),
          ),
        ),
        titlePadding: EdgeInsets.only(left: 20.w, bottom: 16.h),
        collapseMode: CollapseMode.parallax,
      ),
      actions: [
        Padding(
          padding: EdgeInsets.only(right: 12.w),
          child: IconButton(
            icon: Icon(Icons.bluetooth_rounded,
                color: Colors.white, size: 22.r),
            onPressed: () => context.push(AppRoutes.devicePairing),
          ),
        ),
      ],
    );
  }

  Widget _buildScoreCard() {
    return Container(
      padding: EdgeInsets.all(20.r),
      decoration: BoxDecoration(
        gradient: AppColors.primaryGradient,
        borderRadius: BorderRadius.circular(20.r),
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
                SizedBox(height: 6.h),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      avgScore.toInt().toString(),
                      style:
                          AppTextStyles.display1.copyWith(color: Colors.white),
                    ),
                    Padding(
                      padding: EdgeInsets.only(bottom: 10.h, left: 4.w),
                      child: Text(
                        '/ 100',
                        style: AppTextStyles.bodyMedium.copyWith(
                            color: Colors.white.withValues(alpha: 0.6)),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 6.h),
                Container(
                  padding:
                      EdgeInsets.symmetric(horizontal: 10.w, vertical: 4.h),
                  decoration: BoxDecoration(
                    color: AppColors.accent.withValues(alpha: 0.25),
                    borderRadius: BorderRadius.circular(20.r),
                  ),
                  child: Text(
                    '↑ 3 pts from last week',
                    style: AppTextStyles.labelSmall
                        .copyWith(color: AppColors.accent),
                  ),
                ),
                SizedBox(height: 12.h),
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
      crossAxisSpacing: 12.w,
      mainAxisSpacing: 12.h,
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
          Text('Weekly Score Trend', style: AppTextStyles.h3),
          SizedBox(height: 4.h),
          Text('Last 7 days', style: AppTextStyles.bodySmall),
          SizedBox(height: 20.h),
          SizedBox(
            height: 140.h,
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
                          padding: EdgeInsets.only(top: 6.h),
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
                        width: 28.w,
                        borderRadius: BorderRadius.circular(6.r),
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

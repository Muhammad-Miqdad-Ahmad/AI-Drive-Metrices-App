import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_text_styles.dart';
import '../../core/services/supabase_service.dart';
import '../../core/storage/local_storage_service.dart';
import '../../models/models.dart';
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
  // ── State ─────────────────────────────────────────────────────────────────
  bool _loading = true;
  String? _error;

  UserModel? _user;
  String? _deviceToken;
  DashboardStats _stats = DashboardStats.empty();
  List<TripModel> _recentTrips = [];
  List<Map<String, dynamic>> _weeklyScores = _emptyWeekly();

  // ── Init ──────────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      _user = await LocalStorageService.getCurrentUser();
      _deviceToken = await LocalStorageService.getDeviceToken();

      if (_deviceToken == null) {
        setState(() { _loading = false; });
        return;
      }

      final svc = SupabaseService(deviceToken: _deviceToken!);
      final results = await Future.wait([
        svc.getDashboardStats(),
        svc.getRecentTrips(limit: 2),
        svc.getWeeklyScores(),
      ]);

      setState(() {
        _stats = results[0] as DashboardStats;
        _recentTrips = results[1] as List<TripModel>;
        _weeklyScores = results[2] as List<Map<String, dynamic>>;
        _loading = false;
      });
    } catch (e) {
      setState(() { _error = e.toString(); _loading = false; });
    }
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: RefreshIndicator(
        onRefresh: _load,
        color: AppColors.primary,
        child: CustomScrollView(
          slivers: [
            _buildHeader(),
            if (_loading)
              const SliverFillRemaining(
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_error != null)
              SliverFillRemaining(child: _ErrorState(message: _error!, onRetry: _load))
            else if (_deviceToken == null)
              SliverFillRemaining(child: _NoPairingState(onPair: () => context.push(AppRoutes.devicePairing)))
            else
              SliverPadding(
                padding: EdgeInsets.all(20.r),
                sliver: SliverList(
                  delegate: SliverChildListDelegate([
                    _buildScoreCard(),
                    SizedBox(height: 20.h),
                    SectionHeader(
                      title: 'This Week',
                      action: 'See All',
                      onAction: () => context.go(AppRoutes.trips),
                    ),
                    SizedBox(height: 12.h),
                    _buildQuickStats(),
                    SizedBox(height: 20.h),
                    _buildWeeklyChart(),
                    SizedBox(height: 20.h),
                    SectionHeader(
                      title: 'Recent Trips',
                      action: 'View All',
                      onAction: () => context.go(AppRoutes.trips),
                    ),
                    SizedBox(height: 12.h),
                    if (_recentTrips.isEmpty)
                      const _NoTripsYet()
                    else
                      ..._recentTrips.map(
                        (trip) => Padding(
                          padding: EdgeInsets.only(bottom: 12.h),
                          child: TripCard(
                            trip: trip,
                            onTap: () => context.push('/trips/${trip.id}', extra: trip),
                          ),
                        ),
                      ),
                    SizedBox(height: 20.h),
                  ]),
                ),
              ),
          ],
        ),
      ),
    );
  }

  // ── Header ────────────────────────────────────────────────────────────────

  Widget _buildHeader() {
    final firstName = _user?.fullName.split(' ').first ?? 'Driver';
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
                          'Good ${_greeting()},',
                          style: AppTextStyles.bodyMedium
                              .copyWith(color: Colors.white.withValues(alpha: 0.7)),
                        ),
                        Text(
                          firstName,
                          style: AppTextStyles.h2.copyWith(color: Colors.white),
                        ),
                        SizedBox(height: 4.h),
                        Container(
                          padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 4.h),
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
                                decoration: BoxDecoration(
                                  color: _deviceToken != null
                                      ? AppColors.accent
                                      : AppColors.warning,
                                  shape: BoxShape.circle,
                                ),
                              ),
                              SizedBox(width: 6.w),
                              Text(
                                _deviceToken != null
                                    ? 'Device Connected'
                                    : 'No Device Paired',
                                style: AppTextStyles.labelSmall
                                    .copyWith(color: Colors.white),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    width: 40.r,
                    height: 40.r,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12.r),
                    ),
                    child: Icon(Icons.notifications_outlined,
                        color: Colors.white, size: 20.r),
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
            icon: Icon(Icons.bluetooth_rounded, color: Colors.white, size: 22.r),
            onPressed: () => context.push(AppRoutes.devicePairing),
          ),
        ),
      ],
    );
  }

  // ── Score card ────────────────────────────────────────────────────────────

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
                      _stats.avgScore.toInt().toString(),
                      style: AppTextStyles.display1.copyWith(color: Colors.white),
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
                  padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 4.h),
                  decoration: BoxDecoration(
                    color: AppColors.accent.withValues(alpha: 0.25),
                    borderRadius: BorderRadius.circular(20.r),
                  ),
                  child: Text(
                    'Grade ${DriverScoreModel.gradeFromScore(_stats.avgScore)}',
                    style: AppTextStyles.labelSmall.copyWith(color: AppColors.accent),
                  ),
                ),
                SizedBox(height: 12.h),
                Text(
                  '${_stats.totalTrips} trips recorded',
                  style: AppTextStyles.bodySmall
                      .copyWith(color: Colors.white.withValues(alpha: 0.6)),
                ),
              ],
            ),
          ),
          ScoreGaugeWidget(score: _stats.avgScore, size: 130, showLabel: false),
        ],
      ),
    );
  }

  // ── Quick stats grid ──────────────────────────────────────────────────────

  Widget _buildQuickStats() {
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
          value: _stats.totalKm.toStringAsFixed(0),
          unit: 'km',
          icon: Icons.route_rounded,
        ),
        StatCard(
          label: 'Total Trips',
          value: '${_stats.totalTrips}',
          icon: Icons.directions_car_rounded,
          iconColor: AppColors.accent,
          iconBg: AppColors.accentLight,
        ),
        StatCard(
          label: 'Harsh Events',
          value: '${_stats.totalHarshEvents}',
          icon: Icons.warning_amber_rounded,
          iconColor: AppColors.warning,
          iconBg: AppColors.warningLight,
        ),
        StatCard(
          label: 'Best Score',
          value: _stats.bestScore.toInt().toString(),
          icon: Icons.emoji_events_rounded,
          iconColor: AppColors.success,
          iconBg: AppColors.successLight,
        ),
      ],
    );
  }

  // ── Weekly chart ──────────────────────────────────────────────────────────

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
                        if (idx < 0 || idx >= _weeklyScores.length) {
                          return const SizedBox.shrink();
                        }
                        return Padding(
                          padding: EdgeInsets.only(top: 6.h),
                          child: Text(
                            _weeklyScores[idx]['day'] as String,
                            style: AppTextStyles.overline,
                          ),
                        );
                      },
                    ),
                  ),
                  leftTitles:
                      const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles:
                      const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  topTitles:
                      const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                ),
                gridData: const FlGridData(show: false),
                borderData: FlBorderData(show: false),
                barGroups: _weeklyScores.asMap().entries.map((entry) {
                  final idx = entry.key;
                  final score = (entry.value['score'] as num).toDouble();
                  final isToday = idx == _weeklyScores.length - 1;
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
                                  AppColors.scoreColor(score).withValues(alpha: 0.4),
                                  AppColors.scoreColor(score).withValues(alpha: 0.7),
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

  // ── Helpers ───────────────────────────────────────────────────────────────

  String _greeting() {
    final h = DateTime.now().hour;
    if (h < 12) return 'Morning';
    if (h < 17) return 'Afternoon';
    return 'Evening';
  }

  static List<Map<String, dynamic>> _emptyWeekly() {
    const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return days.map((d) => {'day': d, 'score': 0.0}).toList();
  }
}

// ── Empty / error states ───────────────────────────────────────────────────

class _NoPairingState extends StatelessWidget {
  final VoidCallback onPair;
  const _NoPairingState({required this.onPair});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(32.r),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80.r,
              height: 80.r,
              decoration: BoxDecoration(
                color: AppColors.primarySurface,
                borderRadius: BorderRadius.circular(24.r),
              ),
              child: Icon(Icons.bluetooth_searching_rounded,
                  size: 40.r, color: AppColors.primary),
            ),
            SizedBox(height: 20.h),
            Text('No Device Paired', style: AppTextStyles.h3),
            SizedBox(height: 8.h),
            Text(
              'Pair your STM32 device to start recording trips and viewing your driving score.',
              style: AppTextStyles.bodyMedium,
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 24.h),
            ElevatedButton.icon(
              onPressed: onPair,
              icon: const Icon(Icons.bluetooth_rounded),
              label: const Text('Pair Device'),
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const _ErrorState({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(32.r),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.cloud_off_rounded, size: 48.r, color: AppColors.danger),
            SizedBox(height: 16.h),
            Text('Failed to load data', style: AppTextStyles.h3),
            SizedBox(height: 8.h),
            Text(message,
                style: AppTextStyles.bodySmall, textAlign: TextAlign.center),
            SizedBox(height: 24.h),
            ElevatedButton(onPressed: onRetry, child: const Text('Retry')),
          ],
        ),
      ),
    );
  }
}

class _NoTripsYet extends StatelessWidget {
  const _NoTripsYet();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(24.r),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          Icon(Icons.route_rounded, size: 40.r, color: AppColors.textSecondary),
          SizedBox(height: 12.h),
          Text('No trips yet', style: AppTextStyles.bodyMedium),
          SizedBox(height: 4.h),
          Text(
            'Your trips will appear here once the device syncs.',
            style: AppTextStyles.bodySmall,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
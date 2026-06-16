import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_text_styles.dart';
import '../../core/services/supabase_service.dart';
import '../../core/storage/local_storage_service.dart';
import '../../core/utils/date_formatter.dart';
import '../../models/models.dart';

class TripHistoryScreen extends StatefulWidget {
  const TripHistoryScreen({super.key});

  @override
  State<TripHistoryScreen> createState() => _TripHistoryScreenState();
}

class _TripHistoryScreenState extends State<TripHistoryScreen>
    with SingleTickerProviderStateMixin {
  bool _loading = true;
  String? _error;
  List<TripModel> _trips = [];
  String _filter = 'All';
  String _sortBy = 'Date';
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _tabController.addListener(() {
      const filters = ['All', 'Good', 'Fair', 'Poor'];
      if (!_tabController.indexIsChanging) {
        setState(() => _filter = filters[_tabController.index]);
      }
    });
    _load();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final token = await LocalStorageService.getDeviceToken();
      if (token == null) {
        setState(() {
          _trips = [];
          _loading = false;
        });
        return;
      }
      final svc = SupabaseService(deviceToken: token);
      final trips = await svc.getRecentTrips(limit: 100);
      if (trips.isEmpty) await svc.debugDump();
      setState(() {
        _trips = trips;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  List<TripModel> get _filtered {
    List<TripModel> result;
    switch (_filter) {
      case 'Good':
        result = _trips.where((t) => t.score.overall >= 80).toList();
        break;
      case 'Fair':
        result = _trips
            .where((t) => t.score.overall >= 60 && t.score.overall < 80)
            .toList();
        break;
      case 'Poor':
        result = _trips.where((t) => t.score.overall < 60).toList();
        break;
      default:
        result = List.from(_trips);
    }
    switch (_sortBy) {
      case 'Score':
        result.sort((a, b) => b.score.overall.compareTo(a.score.overall));
        break;
      case 'Distance':
        result.sort((a, b) => b.distanceKm.compareTo(a.distanceKm));
        break;
      default:
        result.sort((a, b) => b.startTime.compareTo(a.startTime));
    }
    return result;
  }

  double get _avgScore => _trips.isEmpty
      ? 0
      : _trips.map((t) => t.score.overall).reduce((a, b) => a + b) /
          _trips.length;
  double get _totalDistance => _trips.fold(0.0, (sum, t) => sum + t.distanceKm);
  int get _totalEvents => _trips.fold(0, (sum, t) => sum + t.harshEventCount);
  int get _goodTrips => _trips.where((t) => t.score.overall >= 80).length;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: NestedScrollView(
        headerSliverBuilder: (context, innerBoxIsScrolled) => [
          SliverAppBar(
            expandedHeight: _trips.isEmpty ? 60.h : 220.h,
            pinned: true,
            backgroundColor: AppColors.surface,
            elevation: 0,
            title: const Text('Trip History'),
            actions: [
              PopupMenuButton<String>(
                icon: const Icon(Icons.sort_rounded),
                onSelected: (v) => setState(() => _sortBy = v),
                itemBuilder: (_) => ['Date', 'Score', 'Distance']
                    .map((s) => PopupMenuItem(
                          value: s,
                          child: Row(children: [
                            if (_sortBy == s)
                              Icon(Icons.check,
                                  size: 16.r, color: AppColors.primary),
                            SizedBox(width: 8.w),
                            Text(s),
                          ]),
                        ))
                    .toList(),
              ),
            ],
            flexibleSpace: FlexibleSpaceBar(
              background: _trips.isNotEmpty && !_loading
                  ? _SummaryBanner(
                      avgScore: _avgScore,
                      totalDistance: _totalDistance,
                      totalTrips: _trips.length,
                      goodTrips: _goodTrips,
                      totalEvents: _totalEvents,
                    )
                  : null,
            ),
            bottom: TabBar(
              controller: _tabController,
              isScrollable: false,
              labelColor: AppColors.primary,
              unselectedLabelColor: AppColors.textSecondary,
              indicatorColor: AppColors.primary,
              indicatorWeight: 3,
              tabs: const [
                Tab(text: 'All'),
                Tab(text: 'Good'),
                Tab(text: 'Fair'),
                Tab(text: 'Poor'),
              ],
            ),
          ),
        ],
        body: _buildBody(),
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.cloud_off_rounded, size: 48.r, color: AppColors.danger),
            SizedBox(height: 12.h),
            Text(_error!,
                style: AppTextStyles.bodySmall, textAlign: TextAlign.center),
            SizedBox(height: 16.h),
            ElevatedButton(onPressed: _load, child: const Text('Retry')),
          ],
        ),
      );
    }

    final displayed = _filtered;
    if (displayed.isEmpty) return _EmptyState(filter: _filter);

    final grouped = <String, List<TripModel>>{};
    for (final trip in displayed) {
      final key = _monthKey(trip.startTime);
      grouped.putIfAbsent(key, () => []).add(trip);
    }

    return RefreshIndicator(
      onRefresh: _load,
      color: AppColors.primary,
      child: ListView.builder(
        padding: EdgeInsets.fromLTRB(20.w, 8.h, 20.w, 24.h),
        itemCount: grouped.length,
        itemBuilder: (context, groupIdx) {
          final month = grouped.keys.elementAt(groupIdx);
          final monthTrips = grouped[month]!;
          final monthAvg =
              monthTrips.map((t) => t.score.overall).reduce((a, b) => a + b) /
                  monthTrips.length;

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(height: 12.h),
              _MonthHeader(
                  month: month, count: monthTrips.length, avgScore: monthAvg),
              SizedBox(height: 8.h),
              ...monthTrips.asMap().entries.map((e) => Padding(
                    padding: EdgeInsets.only(bottom: 10.h),
                    child: _EnhancedTripCard(
                      trip: e.value,
                      onTap: () =>
                          context.push('/trips/${e.value.id}', extra: e.value),
                    ),
                  )),
            ],
          );
        },
      ),
    );
  }

  String _monthKey(DateTime dt) {
    const months = [
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December'
    ];
    return '${months[dt.month - 1]} ${dt.year}';
  }
}

// ── Summary banner ────────────────────────────────────────────────────────

class _SummaryBanner extends StatelessWidget {
  final double avgScore;
  final double totalDistance;
  final int totalTrips;
  final int goodTrips;
  final int totalEvents;

  const _SummaryBanner({
    required this.avgScore,
    required this.totalDistance,
    required this.totalTrips,
    required this.goodTrips,
    required this.totalEvents,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(20.w, 72.h, 20.w, 52.h),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF0A2463), Color(0xFF0057FF)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Row(
        children: [
          _BannerStat(
              value: avgScore.toInt().toString(),
              label: 'Avg Score',
              icon: Icons.shield_outlined),
          _BannerDivider(),
          _BannerStat(
              value: '${totalDistance.toStringAsFixed(0)} km',
              label: 'Total Dist',
              icon: Icons.route_rounded),
          _BannerDivider(),
          _BannerStat(
              value: '$goodTrips/$totalTrips',
              label: 'Good Trips',
              icon: Icons.thumb_up_outlined),
          _BannerDivider(),
          _BannerStat(
              value: totalEvents.toString(),
              label: 'Events',
              icon: Icons.warning_amber_rounded),
        ],
      ),
    );
  }
}

class _BannerStat extends StatelessWidget {
  final String value;
  final String label;
  final IconData icon;
  const _BannerStat(
      {required this.value, required this.label, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14.r, color: Colors.white70),
          SizedBox(height: 2.h),
          Text(value,
              style: AppTextStyles.h4.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 13.sp,
                  height: 1.1)),
          Text(label,
              style: AppTextStyles.overline.copyWith(
                  color: Colors.white60, fontSize: 9.sp, height: 1.1)),
        ],
      ),
    );
  }
}

class _BannerDivider extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(width: 1.w, height: 40.h, color: Colors.white24);
  }
}

// ── Month header ──────────────────────────────────────────────────────────

class _MonthHeader extends StatelessWidget {
  final String month;
  final int count;
  final double avgScore;
  const _MonthHeader(
      {required this.month, required this.count, required this.avgScore});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(month,
            style: AppTextStyles.labelLarge
                .copyWith(color: AppColors.textSecondary)),
        SizedBox(width: 8.w),
        Container(
          padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 2.h),
          decoration: BoxDecoration(
            color: AppColors.surfaceVariant,
            borderRadius: BorderRadius.circular(8.r),
          ),
          child: Text('$count trips', style: AppTextStyles.overline),
        ),
        const Spacer(),
        Container(
          padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 2.h),
          decoration: BoxDecoration(
            color: AppColors.scoreColorLight(avgScore),
            borderRadius: BorderRadius.circular(8.r),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.bar_chart_rounded,
                  size: 12.r, color: AppColors.scoreColor(avgScore)),
              SizedBox(width: 4.w),
              Text(
                'Avg ${avgScore.toInt()}',
                style: AppTextStyles.overline
                    .copyWith(color: AppColors.scoreColor(avgScore)),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ── Enhanced trip card ────────────────────────────────────────────────────

class _EnhancedTripCard extends StatelessWidget {
  final TripModel trip;
  final VoidCallback onTap;
  const _EnhancedTripCard({required this.trip, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final score = trip.score.overall;
    final scoreColor = AppColors.scoreColor(score);
    final scoreColorLight = AppColors.scoreColorLight(score);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16.r),
          border: Border.all(color: AppColors.border),
          boxShadow: AppColors.cardShadow,
        ),
        child: Column(
          children: [
            Padding(
              padding: EdgeInsets.all(14.r),
              child: Row(
                children: [
                  Container(
                    width: 52.r,
                    height: 52.r,
                    decoration: BoxDecoration(
                      color: scoreColorLight,
                      borderRadius: BorderRadius.circular(14.r),
                      border: Border.all(
                          color: scoreColor.withValues(alpha: 0.3), width: 1.5),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          score.toInt().toString(),
                          style: TextStyle(
                            fontSize: 15.sp,
                            fontWeight: FontWeight.bold,
                            color: scoreColor,
                            height: 1.1,
                          ),
                        ),
                        Text(
                          trip.score.grade,
                          style: TextStyle(
                              fontSize: 9.sp,
                              color: scoreColor,
                              fontWeight: FontWeight.w600,
                              height: 1.1),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(width: 12.w),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(DateFormatter.tripDate(trip.startTime),
                            style: AppTextStyles.labelLarge),
                        SizedBox(height: 2.h),
                        Text(DateFormatter.time(trip.startTime),
                            style: AppTextStyles.bodySmall),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Row(
                        children: [
                          if (trip.harshEventCount > 0) ...[
                            Container(
                              padding: EdgeInsets.symmetric(
                                  horizontal: 6.w, vertical: 3.h),
                              decoration: BoxDecoration(
                                color: AppColors.dangerLight,
                                borderRadius: BorderRadius.circular(6.r),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.warning_amber_rounded,
                                      size: 10.r, color: AppColors.danger),
                                  SizedBox(width: 3.w),
                                  Text(
                                    '${trip.harshEventCount}',
                                    style: TextStyle(
                                        fontSize: 10.sp,
                                        color: AppColors.danger,
                                        fontWeight: FontWeight.bold),
                                  ),
                                ],
                              ),
                            ),
                            if (trip.worstHarshnessLabel != null) ...[
                              SizedBox(width: 4.w),
                              _HarshnessBadge(
                                label: trip.worstHarshnessLabel!,
                                gForce: trip.worstGForce!,
                              ),
                            ],
                          ],
                          SizedBox(width: 6.w),
                          const Icon(Icons.chevron_right_rounded,
                              color: AppColors.textTertiary),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Container(
              padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 10.h),
              decoration: BoxDecoration(
                color: AppColors.surfaceVariant,
                borderRadius:
                    BorderRadius.vertical(bottom: Radius.circular(16.r)),
              ),
              child: Row(
                children: [
                  _MiniStat(
                      icon: Icons.route_rounded,
                      value: '${trip.distanceKm.toStringAsFixed(1)} km'),
                  _StatDot(),
                  _MiniStat(
                      icon: Icons.timer_outlined, value: trip.durationLabel),
                  _StatDot(),
                  _MiniStat(
                      icon: Icons.speed_rounded,
                      value: '${trip.maxSpeedKmh.toInt()} km/h max'),
                  const Spacer(),
                  _ScoreBar(score: score, color: scoreColor),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MiniStat extends StatelessWidget {
  final IconData icon;
  final String value;
  const _MiniStat({required this.icon, required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 12.r, color: AppColors.textTertiary),
        SizedBox(width: 3.w),
        Text(value, style: AppTextStyles.overline),
      ],
    );
  }
}

class _StatDot extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 3.r,
      height: 3.r,
      margin: EdgeInsets.symmetric(horizontal: 6.w),
      decoration: const BoxDecoration(
          color: AppColors.textTertiary, shape: BoxShape.circle),
    );
  }
}

class _ScoreBar extends StatelessWidget {
  final double score;
  final Color color;
  const _ScoreBar({required this.score, required this.color});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 48.w,
      height: 6.h,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(3.r),
        child: LinearProgressIndicator(
          value: score / 100,
          backgroundColor: AppColors.border,
          valueColor: AlwaysStoppedAnimation<Color>(color),
        ),
      ),
    );
  }
}

// ── Harshness badge ───────────────────────────────────────────────────────

class _HarshnessBadge extends StatelessWidget {
  final String label;
  final double gForce;
  const _HarshnessBadge({required this.label, required this.gForce});

  Color get _color {
    if (gForce < 0.3) return const Color(0xFFF59E0B); // amber
    if (gForce < 0.6) return const Color(0xFFF97316); // orange
    return const Color(0xFFEF4444); // red
  }

  @override
  Widget build(BuildContext context) {
    final color = _color;
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 5.w, vertical: 3.h),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(5.r),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Text(
        '${gForce.toStringAsFixed(2)}g · $label',
        style: TextStyle(
          fontSize: 8.5.sp,
          color: color,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

// ── Empty state ───────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  final String filter;
  const _EmptyState({required this.filter});

  @override
  Widget build(BuildContext context) {
    return Center(
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
            child:
                Icon(Icons.route_rounded, size: 40.r, color: AppColors.primary),
          ),
          SizedBox(height: 20.h),
          Text(filter == 'All' ? 'No trips yet' : 'No $filter trips',
              style: AppTextStyles.h3),
          SizedBox(height: 8.h),
          Text(
            filter == 'All'
                ? 'Connect your device and start driving'
                : 'Try a different filter',
            style: AppTextStyles.bodyMedium,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
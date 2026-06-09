import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_text_styles.dart';
import '../../core/services/supabase_service.dart';
import '../../core/storage/local_storage_service.dart';
import '../../core/utils/date_formatter.dart';
import '../../models/models.dart';
import '../../widgets/trip/trip_card_widget.dart';

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

  // ── Summary stats across all trips ──────────────────────────────────────

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
            expandedHeight: _trips.isEmpty ? 60 : 200,
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
                              const Icon(Icons.check,
                                  size: 16, color: AppColors.primary),
                            const SizedBox(width: 8),
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
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.cloud_off_rounded,
                size: 48, color: AppColors.danger),
            const SizedBox(height: 12),
            Text(_error!,
                style: AppTextStyles.bodySmall, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            ElevatedButton(onPressed: _load, child: const Text('Retry')),
          ],
        ),
      );
    }

    final displayed = _filtered;
    if (displayed.isEmpty) return _EmptyState(filter: _filter);

    // Group by month
    final grouped = <String, List<TripModel>>{};
    for (final trip in displayed) {
      final key = _monthKey(trip.startTime);
      grouped.putIfAbsent(key, () => []).add(trip);
    }

    return RefreshIndicator(
      onRefresh: _load,
      color: AppColors.primary,
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
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
              const SizedBox(height: 12),
              _MonthHeader(
                  month: month, count: monthTrips.length, avgScore: monthAvg),
              const SizedBox(height: 8),
              ...monthTrips.asMap().entries.map((e) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
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
      padding: const EdgeInsets.fromLTRB(20, 72, 20, 8),
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
            icon: Icons.shield_outlined,
          ),
          _BannerDivider(),
          _BannerStat(
            value: '${totalDistance.toStringAsFixed(0)} km',
            label: 'Total Dist',
            icon: Icons.route_rounded,
          ),
          _BannerDivider(),
          _BannerStat(
            value: '$goodTrips/$totalTrips',
            label: 'Good Trips',
            icon: Icons.thumb_up_outlined,
          ),
          _BannerDivider(),
          _BannerStat(
            value: totalEvents.toString(),
            label: 'Events',
            icon: Icons.warning_amber_rounded,
          ),
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
        children: [
          Icon(icon, size: 18, color: Colors.white70),
          const SizedBox(height: 4),
          Text(value,
              style: AppTextStyles.h4
                  .copyWith(color: Colors.white, fontWeight: FontWeight.bold)),
          Text(label,
              style: AppTextStyles.overline.copyWith(color: Colors.white60)),
        ],
      ),
    );
  }
}

class _BannerDivider extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(width: 1, height: 40, color: Colors.white24);
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
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(
            color: AppColors.surfaceVariant,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text('$count trips', style: AppTextStyles.overline),
        ),
        const Spacer(),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(
            color: AppColors.scoreColorLight(avgScore),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.bar_chart_rounded,
                  size: 12, color: AppColors.scoreColor(avgScore)),
              const SizedBox(width: 4),
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
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border),
          boxShadow: AppColors.cardShadow,
        ),
        child: Column(
          children: [
            // Header row
            Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  // Score badge
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      color: scoreColorLight,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                          color: scoreColor.withValues(alpha: 0.3), width: 1.5),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          score.toInt().toString(),
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: scoreColor,
                          ),
                        ),
                        Text(
                          trip.score.grade,
                          style: TextStyle(
                              fontSize: 10,
                              color: scoreColor,
                              fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          DateFormatter.tripDate(trip.startTime),
                          style: AppTextStyles.labelLarge,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          DateFormatter.time(trip.startTime),
                          style: AppTextStyles.bodySmall,
                        ),
                      ],
                    ),
                  ),
                  // Score bar indicator
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Row(
                        children: [
                          if (trip.harshEventCount > 0)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 3),
                              decoration: BoxDecoration(
                                color: AppColors.dangerLight,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.warning_amber_rounded,
                                      size: 10, color: AppColors.danger),
                                  const SizedBox(width: 3),
                                  Text(
                                    '${trip.harshEventCount}',
                                    style: const TextStyle(
                                        fontSize: 10,
                                        color: AppColors.danger,
                                        fontWeight: FontWeight.bold),
                                  ),
                                ],
                              ),
                            ),
                          const SizedBox(width: 6),
                          const Icon(Icons.chevron_right_rounded,
                              color: AppColors.textTertiary),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
            // Stats bar
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: const BoxDecoration(
                color: AppColors.surfaceVariant,
                borderRadius:
                    BorderRadius.vertical(bottom: Radius.circular(16)),
              ),
              child: Row(
                children: [
                  _MiniStat(
                    icon: Icons.route_rounded,
                    value: '${trip.distanceKm.toStringAsFixed(1)} km',
                  ),
                  _StatDot(),
                  _MiniStat(
                    icon: Icons.timer_outlined,
                    value: trip.durationLabel,
                  ),
                  _StatDot(),
                  _MiniStat(
                    icon: Icons.speed_rounded,
                    value: '${trip.maxSpeedKmh.toInt()} km/h max',
                  ),
                  const Spacer(),
                  // Score mini-bar
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
        Icon(icon, size: 12, color: AppColors.textTertiary),
        const SizedBox(width: 3),
        Text(value, style: AppTextStyles.overline),
      ],
    );
  }
}

class _StatDot extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 3,
      height: 3,
      margin: const EdgeInsets.symmetric(horizontal: 6),
      decoration: const BoxDecoration(
        color: AppColors.textTertiary,
        shape: BoxShape.circle,
      ),
    );
  }
}

class _ScoreBar extends StatelessWidget {
  final double score;
  final Color color;

  const _ScoreBar({required this.score, required this.color});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: 48,
          height: 6,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: LinearProgressIndicator(
              value: score / 100,
              backgroundColor: AppColors.border,
              valueColor: AlwaysStoppedAnimation<Color>(color),
            ),
          ),
        ),
      ],
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
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: AppColors.primarySurface,
              borderRadius: BorderRadius.circular(24),
            ),
            child: const Icon(Icons.route_rounded,
                size: 40, color: AppColors.primary),
          ),
          const SizedBox(height: 20),
          Text(
            filter == 'All' ? 'No trips yet' : 'No $filter trips',
            style: AppTextStyles.h3,
          ),
          const SizedBox(height: 8),
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

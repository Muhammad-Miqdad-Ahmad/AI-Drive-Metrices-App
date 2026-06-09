import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_text_styles.dart';
import '../../core/services/supabase_service.dart';
import '../../core/storage/local_storage_service.dart';
import '../../models/models.dart';
import '../../widgets/trip/trip_card_widget.dart';

class TripHistoryScreen extends StatefulWidget {
  const TripHistoryScreen({super.key});

  @override
  State<TripHistoryScreen> createState() => _TripHistoryScreenState();
}

class _TripHistoryScreenState extends State<TripHistoryScreen> {
  bool _loading = true;
  String? _error;
  List<TripModel> _trips = [];
  String _filter = 'All';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final token = await LocalStorageService.getDeviceToken();
      if (token == null) {
        setState(() { _trips = []; _loading = false; });
        return;
      }
      final svc = SupabaseService(deviceToken: token);
      final trips = await svc.getRecentTrips(limit: 100);
      setState(() { _trips = trips; _loading = false; });
    } catch (e) {
      setState(() { _error = e.toString(); _loading = false; });
    }
  }

  List<TripModel> get _filtered {
    switch (_filter) {
      case 'Good':
        return _trips.where((t) => t.score.overall >= 80).toList();
      case 'Fair':
        return _trips
            .where((t) => t.score.overall >= 60 && t.score.overall < 80)
            .toList();
      case 'Poor':
        return _trips.where((t) => t.score.overall < 60).toList();
      default:
        return _trips;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Trip History'),
        backgroundColor: AppColors.surface,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(52),
          child: _FilterChips(
            selected: _filter,
            onSelected: (v) => setState(() => _filter = v),
          ),
        ),
      ),
      body: _buildBody(),
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
            const Icon(Icons.cloud_off_rounded, size: 48, color: AppColors.danger),
            const SizedBox(height: 12),
            Text(_error!, style: AppTextStyles.bodySmall, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            ElevatedButton(onPressed: _load, child: const Text('Retry')),
          ],
        ),
      );
    }

    final displayed = _filtered;
    if (displayed.isEmpty) return _EmptyState(filter: _filter);

    return RefreshIndicator(
      onRefresh: _load,
      color: AppColors.primary,
      child: ListView.separated(
        padding: const EdgeInsets.all(20),
        itemCount: displayed.length,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (context, index) {
          final trip = displayed[index];
          return TripCard(
            trip: trip,
            onTap: () => context.push('/trips/${trip.id}', extra: trip),
          );
        },
      ),
    );
  }
}

class _FilterChips extends StatelessWidget {
  final String selected;
  final ValueChanged<String> onSelected;
  static const _filters = ['All', 'Good', 'Fair', 'Poor'];

  const _FilterChips({required this.selected, required this.onSelected});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 52,
      color: AppColors.surface,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        scrollDirection: Axis.horizontal,
        itemCount: _filters.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, i) {
          final f = _filters[i];
          final isSelected = f == selected;
          return GestureDetector(
            onTap: () => onSelected(f),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              decoration: BoxDecoration(
                color: isSelected ? AppColors.primary : AppColors.surfaceVariant,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                f,
                style: AppTextStyles.labelMedium.copyWith(
                  color: isSelected ? Colors.white : AppColors.textSecondary,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

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

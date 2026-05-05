import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_text_styles.dart';
import '../../core/services/mock_data_service.dart';
import '../../models/models.dart';
import '../../widgets/trip/trip_card_widget.dart';

class TripHistoryScreen extends StatefulWidget {
  const TripHistoryScreen({super.key});

  @override
  State<TripHistoryScreen> createState() => _TripHistoryScreenState();
}

class _TripHistoryScreenState extends State<TripHistoryScreen> {
  final trips = MockDataService.trips;
  String _filter = 'All';

  List<TripModel> get filteredTrips {
    switch (_filter) {
      case 'Good':
        return trips.where((t) => t.score.overall >= 80).toList();
      case 'Fair':
        return trips
            .where((t) => t.score.overall >= 60 && t.score.overall < 80)
            .toList();
      case 'Poor':
        return trips.where((t) => t.score.overall < 60).toList();
      default:
        return trips;
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
      body: filteredTrips.isEmpty
          ? _EmptyState()
          : ListView.separated(
              padding: const EdgeInsets.all(20),
              itemCount: filteredTrips.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final trip = filteredTrips[index];
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
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
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
          const Text('No trips found', style: AppTextStyles.h3),
          const SizedBox(height: 8),
          const Text(
            'Connect your device and start driving',
            style: AppTextStyles.bodyMedium,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

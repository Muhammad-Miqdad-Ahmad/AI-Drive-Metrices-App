import 'package:flutter/material.dart';
import '../../core/constants/dummy_data.dart';
import '../../widgets/cards/trip_card.dart';
import '../../core/theme/app_colors.dart';
import 'trip_detail_screen.dart';

class TripsScreen extends StatefulWidget {
  const TripsScreen({super.key});

  @override
  State<TripsScreen> createState() => _TripsScreenState();
}

class _TripsScreenState extends State<TripsScreen> {
  final TextEditingController _searchController = TextEditingController();
  List<Map<String, dynamic>> filteredTrips = DummyData.trips;

  void _filterTrips(String query) {
    final allTrips = DummyData.trips;

    setState(() {
      filteredTrips = allTrips
          .where(
            (trip) => trip["date"].toLowerCase().contains(query.toLowerCase()),
          )
          .toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text(
          "Trip History",
          style: TextStyle(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
      ),
      body: Column(
        children: [
          /// SEARCH BAR
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _searchController,
              onChanged: _filterTrips,
              style: const TextStyle(color: AppColors.textPrimary),
              decoration: InputDecoration(
                hintText: "Search by date...",
                hintStyle: const TextStyle(color: AppColors.textSecondary),
                filled: true,
                fillColor: AppColors.cardWhite,
                prefixIcon: const Icon(
                  Icons.search,
                  color: AppColors.primaryPurple,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide.none,
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),

          /// LIST
          Expanded(
            child: filteredTrips.isEmpty
                ? Center(
                    child: Text(
                      "No trips found",
                      style: TextStyle(color: AppColors.textSecondary),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: filteredTrips.length,
                    itemBuilder: (context, index) {
                      final trip = filteredTrips[index];

                      return TripCard(
                        date: trip["date"],
                        duration: trip["duration"],
                        score: trip["score"],
                        events: trip["events"],
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => TripDetailScreen(tripData: trip),
                            ),
                          );
                        },
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

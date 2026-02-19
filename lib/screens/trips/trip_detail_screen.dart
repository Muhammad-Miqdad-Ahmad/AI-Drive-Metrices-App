import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../core/theme/app_colors.dart';
//import '../../widgets/charts/live_map_widget.dart';
import '../../widgets/charts/speed_chart.dart';

class TripDetailScreen extends StatelessWidget {
  final Map<String, dynamic> tripData;

  const TripDetailScreen({super.key, required this.tripData});

  @override
  Widget build(BuildContext context) {
    final double score = (tripData["score"] ?? 0).toDouble();

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text(
          "Trip Details",
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        backgroundColor: AppColors.primaryPurple,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // MAP WITH ROUTE

         //   const ClipRRect(
           //   borderRadius: BorderRadius.all(Radius.circular(18)),
          //    child: SizedBox(height: 200, child: LiveMapWidget()),
           // ),

            const SizedBox(height: 20),

            /// TRIP SUMMARY CARD
            _buildInfo(score),

            const SizedBox(height: 20),

            /// SPEED GRAPH
            const Text(
              "Speed Analysis",
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.cardWhite,
                borderRadius: BorderRadius.circular(18),
              ),
              child: SpeedChart(trendData: const [40, 60, 55, 72, 65, 80, 70]),
            ),

            const SizedBox(height: 20),

            /// EVENTS SECTION
            const Text(
              "Safety Events",
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 12),
            _event(
              "Harsh Braking",
              Icons.front_hand,
              Colors.redAccent,
              tripData["harshBrakes"] ?? 0,
            ),
            _event(
              "Overspeeding",
              Icons.speed,
              Colors.orangeAccent,
              tripData["overspeed"] ?? 0,
            ),
            _event(
              "Rapid Acceleration",
              Icons.trending_up,
              Colors.blueAccent,
              tripData["acceleration"] ?? 0,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfo(double score) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.cardWhite,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10),
        ],
      ),
      child: Row(
        children: [
          // Small Score Indicator
          SizedBox(
            height: 60,
            width: 60,
            child: Stack(
              children: [
                PieChart(
                  PieChartData(
                    sectionsSpace: 0,
                    centerSpaceRadius: 20,
                    sections: [
                      PieChartSectionData(
                        color: AppColors.primaryPurple,
                        value: score,
                        radius: 5,
                        showTitle: false,
                      ),
                      PieChartSectionData(
                        color: Colors.grey.shade100,
                        value: 100 - score,
                        radius: 5,
                        showTitle: false,
                      ),
                    ],
                  ),
                ),
                Center(
                  child: Text(
                    "${score.toInt()}",
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                tripData["date"],
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: AppColors.textPrimary,
                ),
              ),
              Text(
                "Overall Safety Score",
                style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _event(String label, IconData icon, Color color, int count) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.cardWhite,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Icon(icon, color: color),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Text(
            "$count",
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}

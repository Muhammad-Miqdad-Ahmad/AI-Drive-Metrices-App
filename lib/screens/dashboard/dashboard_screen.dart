import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/constants/dummy_data.dart';
import '../../widgets/cards/score_card.dart';
import '../../widgets/cards/summary_card.dart';
import '../../widgets/charts/speed_chart.dart';
import '../../widgets/common/custom_button.dart';
// import '../../widgets/charts/live_map_widget.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final dashboard = DummyData.dashboard;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              /// HEADER
              const Text(
                "Driver Dashboard",
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),

              const SizedBox(height: 20),

              /// SCORE
              Center(
                child: ScoreCard(
                  score: dashboard["score"],
                  quality: dashboard["quality"],
                ),
              ),

              const SizedBox(height: 24),

              /// SUMMARY ROW 1
              Row(
                children: [
                  Expanded(
                    child: SummaryCard(
                      title: "Total Trips",
                      value: dashboard["totalTrips"].toString(),
                      icon: Icons.route,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: SummaryCard(
                      title: "Rash Events",
                      value: dashboard["rashEvents"].toString(),
                      icon: Icons.warning_amber_rounded,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 12),

              /// SUMMARY ROW 2
              Row(
                children: [
                  Expanded(
                    child: SummaryCard(
                      title: "Collision Alerts",
                      value: dashboard["collisions"].toString(), // FIXED
                      icon: Icons.car_crash,
                      iconColor: Colors.redAccent,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: SummaryCard(
                      title: "This Week",
                      value: dashboard["weekScore"].toString(),
                      icon: Icons.trending_up,
                      iconColor: Colors.green,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 28),

              /// TREND
              const Text(
                "Driving Trend",
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),

              const SizedBox(height: 12),

              SpeedChart(
                trendData: dashboard["trendData"], // PASS DATA
              ),

              const SizedBox(height: 28),

              /// ACTIONS
              const Text(
                "Quick Actions",
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),

              const SizedBox(height: 12),

              Row(
                children: [
                  Expanded(
                    child: CustomButton(
                      label: "View Trips",
                      icon: Icons.history,
                      onPressed: () {
                        Navigator.pushNamed(context, "/trips");
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: CustomButton(
                      label: "Latest Report",
                      icon: Icons.download,
                      onPressed: () {
                        Navigator.pushNamed(context, "/reports");
                      },
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 12),

              // CustomButton(
              //   label: "Live Tracking",
              //   icon: Icons.location_pin,
              //   fullWidth: true,
              //   onPressed: () {},
              // ),

              // const SizedBox(height: 24),

              // /// MAP
              // const LiveMapWidget(),

              // const SizedBox(height: 30),
            ],
          ),
        ),
      ),
    );
  }
}

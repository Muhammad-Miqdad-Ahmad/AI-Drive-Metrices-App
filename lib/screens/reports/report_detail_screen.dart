import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../core/theme/app_colors.dart';

class ReportDetailScreen extends StatelessWidget {
  final Map<String, dynamic> reportData;

  const ReportDetailScreen({super.key, required this.reportData});

  @override
  Widget build(BuildContext context) {
    final List<double> speedData = [40, 45, 50, 55, 60, 65, 55, 50, 45, 40];
    final double score = (reportData["score"] ?? 0).toDouble();

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text(
          "Trip Analysis",
          style: TextStyle(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: AppColors.textPrimary),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            /// 1. Visual Score Wheel & Main Stats
            _card(
              child: Column(
                children: [
                  Row(
                    children: [
                      // Score Wheel
                      SizedBox(
                        height: 100,
                        width: 100,
                        child: Stack(
                          children: [
                            PieChart(
                              PieChartData(
                                sectionsSpace: 0,
                                centerSpaceRadius: 35,
                                startDegreeOffset: -90,
                                sections: [
                                  PieChartSectionData(
                                    color: AppColors.primaryPurple,
                                    value: score,
                                    radius: 8,
                                    showTitle: false,
                                  ),
                                  PieChartSectionData(
                                    color: Colors.grey.shade200,
                                    value: 100 - score,
                                    radius: 8,
                                    showTitle: false,
                                  ),
                                ],
                              ),
                            ),
                            Center(
                              child: Text(
                                "${score.toInt()}",
                                style: const TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 20),
                      // Quick Summary Text
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              reportData["date"] ?? "N/A",
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 18,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            Text(
                              "Safety Score Performance",
                              style: TextStyle(color: AppColors.textSecondary),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 16),
                    child: Divider(height: 1),
                  ),
                  // Icon-based Info Tiles
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _statTile(
                        Icons.near_me_outlined,
                        reportData["distance"] ?? "0 km",
                        "Distance",
                      ),
                      _statTile(
                        Icons.schedule,
                        reportData["duration"] ?? "0m",
                        "Time",
                      ),
                      _statTile(
                        Icons.auto_graph,
                        "${reportData["events"] ?? 0}",
                        "Events",
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            /// 2. Event Summary with Visual Indicators
            _card(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "Driving Incidents",
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 17,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 16),
                  _visualEventRow(
                    "Harsh Braking",
                    reportData["harshBrakes"] ?? 0,
                    Colors.redAccent,
                    Icons.front_hand,
                  ),
                  _visualEventRow(
                    "Speeding",
                    reportData["overspeed"] ?? 0,
                    Colors.orangeAccent,
                    Icons.speed,
                  ),
                  _visualEventRow(
                    "Rapid Accel.",
                    reportData["acceleration"] ?? 0,
                    Colors.cyan,
                    Icons.trending_up,
                  ),
                  _visualEventRow(
                    "Collisions",
                    reportData["collisions"] ?? 0,
                    Colors.purple,
                    Icons.car_crash,
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            /// 3. Speed Graph
            _card(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        "Speed Profile",
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 17,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      Text(
                        "km/h",
                        style: TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    height: 180,
                    child: LineChart(
                      LineChartData(
                        minX: 0,
                        maxX: speedData.length.toDouble() - 1,
                        minY: 0,
                        maxY: 100,
                        titlesData: FlTitlesData(
                          leftTitles: AxisTitles(
                            sideTitles: SideTitles(
                              showTitles: true,
                              reservedSize: 30,
                              getTitlesWidget: (v, m) => Text(
                                "${v.toInt()}",
                                style: const TextStyle(
                                  fontSize: 10,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ),
                          ),
                          bottomTitles: AxisTitles(
                            sideTitles: SideTitles(
                              showTitles: true,
                              getTitlesWidget: (v, m) => Text(
                                "${v.toInt()}m",
                                style: const TextStyle(
                                  fontSize: 10,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ),
                          ),
                          rightTitles: const AxisTitles(
                            sideTitles: SideTitles(showTitles: false),
                          ),
                          topTitles: const AxisTitles(
                            sideTitles: SideTitles(showTitles: false),
                          ),
                        ),
                        gridData: FlGridData(
                          show: true,
                          drawVerticalLine: false,
                          horizontalInterval: 25,
                          getDrawingHorizontalLine: (v) => FlLine(
                            color: Colors.grey.shade100,
                            strokeWidth: 1,
                          ),
                        ),
                        borderData: FlBorderData(show: false),
                        lineBarsData: [
                          LineChartBarData(
                            spots: List.generate(
                              speedData.length,
                              (i) => FlSpot(i.toDouble(), speedData[i]),
                            ),
                            isCurved: true,
                            color: AppColors.primaryPurple,
                            barWidth: 4,
                            isStrokeCapRound: true,
                            dotData: const FlDotData(show: false),
                            belowBarData: BarAreaData(
                              show: true,
                              color: AppColors.primaryPurple.withOpacity(0.1),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            /// 4. Recommendations
            _card(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "Safety Tips",
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 17,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 12),
                  ...(reportData["recommendations"] ?? []).map<Widget>(
                    (rec) => Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.green.withOpacity(0.05),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.lightbulb_outline,
                            size: 20,
                            color: Colors.green,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              rec,
                              style: const TextStyle(
                                fontSize: 13,
                                color: AppColors.textPrimary,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            /// Action Buttons
            Row(
              children: [
                Expanded(child: _button("Export", Icons.ios_share, () {})),
                const SizedBox(width: 12),
                Expanded(child: _button("Details", Icons.list_alt, () {})),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// Helper for Score/Distance/Time Tiles
  Widget _statTile(IconData icon, String value, String label) {
    return Column(
      children: [
        Icon(icon, color: AppColors.primaryPurple, size: 24),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary,
          ),
        ),
        Text(
          label,
          style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
        ),
      ],
    );
  }

  /// Helper for Incident Rows with Icons
  Widget _visualEventRow(String label, int count, Color color, IconData icon) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                fontWeight: FontWeight.w500,
                color: AppColors.textPrimary,
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              "$count",
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _card({required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.cardWhite,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: child,
    );
  }

  Widget _button(String label, IconData icon, VoidCallback onTap) {
    return ElevatedButton.icon(
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.primaryPurple,
        padding: const EdgeInsets.symmetric(vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      ),
      onPressed: onTap,
      icon: Icon(icon, size: 18, color: Colors.white),
      label: Text(label, style: const TextStyle(color: Colors.white)),
    );
  }
}

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';

class SpeedChart extends StatelessWidget {
  final List<dynamic> trendData;

  const SpeedChart({super.key, required this.trendData});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 200,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: LineChart(
        LineChartData(
          borderData: FlBorderData(show: false),
          gridData: FlGridData(show: true, drawVerticalLine: false),
          titlesData: FlTitlesData(show: false),
          minX: 0,
          maxX: (trendData.length - 1).toDouble(),
          minY: 0,
          maxY: 100,
          lineBarsData: [
            LineChartBarData(
              spots: _buildSpots(),
              isCurved: true,
              color: AppColors.primaryPurple,
              barWidth: 3,
              dotData: FlDotData(show: false),
              belowBarData: BarAreaData(
                show: true,
                color: AppColors.primaryPurple.withOpacity(0.12),
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<FlSpot> _buildSpots() {
    return List.generate(
      trendData.length,
      (index) => FlSpot(index.toDouble(), (trendData[index] as num).toDouble()),
    );
  }
}

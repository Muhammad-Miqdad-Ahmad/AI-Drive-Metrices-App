import 'dart:math';
import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';

class ScoreCard extends StatelessWidget {
  final int score;
  final String quality;

  const ScoreCard({super.key, required this.score, required this.quality});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SizedBox(
          height: 180,
          width: 180,
          child: Stack(
            alignment: Alignment.center,
            children: [
              CustomPaint(
                size: const Size(180, 180),
                painter: GaugePainter(score: score),
              ),
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    "$score",
                    style: const TextStyle(
                      fontSize: 48,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary, // Changed to Dark
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        Text(
          "Driving Quality: $quality",
          style: const TextStyle(color: AppColors.textSecondary, fontSize: 16),
        ),
      ],
    );
  }
}

class GaugePainter extends CustomPainter {
  final int score;
  GaugePainter({required this.score});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;
    const strokeWidth = 14.0;
    const spacing = 0.08;

    final rect = Rect.fromCircle(
      center: center,
      radius: radius - (strokeWidth / 2),
    );

    // Using your primary purple for the 'Excellent' segment
    final List<Map<String, dynamic>> segments = [
      {'start': 0.75, 'end': 0.95, 'color': Colors.redAccent},
      {'start': 0.95, 'end': 1.15, 'color': Colors.orangeAccent},
      {'start': 1.15, 'end': 1.35, 'color': Colors.amber},
      {'start': 1.35, 'end': 1.55, 'color': Colors.lightBlueAccent},
      {'start': 1.55, 'end': 1.75, 'color': AppColors.primaryPurple}, // Purple
    ];

    for (var segment in segments) {
      final paint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.round;

      // Faded background now uses a lighter grey for the white theme
      paint.color = Colors.grey.withOpacity(0.1);
      canvas.drawArc(
        rect,
        segment['start'] * pi,
        (segment['end'] - segment['start'] - spacing) * pi,
        false,
        paint,
      );

      double segmentMaxScore = (segments.indexOf(segment) + 1) * 20.0;
      double segmentMinScore = segmentMaxScore - 20;

      if (score > segmentMinScore) {
        paint.color = segment['color'];
        double fillPercentage = ((score - segmentMinScore) / 20.0).clamp(
          0.0,
          1.0,
        );
        double sweepAngle =
            (segment['end'] - segment['start'] - spacing) * pi * fillPercentage;
        canvas.drawArc(rect, segment['start'] * pi, sweepAngle, false, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

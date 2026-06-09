import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_text_styles.dart';

class ScoreGaugeWidget extends StatefulWidget {
  final double score;
  final double size;
  final bool showLabel;
  final bool animate;

  const ScoreGaugeWidget({
    super.key,
    required this.score,
    this.size = 140,
    this.showLabel = true,
    this.animate = true,
  });

  @override
  State<ScoreGaugeWidget> createState() => _ScoreGaugeWidgetState();
}

class _ScoreGaugeWidgetState extends State<ScoreGaugeWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _animation = Tween<double>(begin: 0, end: widget.score).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic),
    );
    if (widget.animate) _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  String _gradeLabel(double score) {
    if (score >= 90) return 'Excellent';
    if (score >= 80) return 'Good';
    if (score >= 60) return 'Fair';
    return 'Poor';
  }

  @override
  Widget build(BuildContext context) {
    final responsiveSize = widget.size.r;
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, _) {
        final currentScore = widget.animate ? _animation.value : widget.score;
        final color = AppColors.scoreColor(currentScore);

        return SizedBox(
          width: responsiveSize,
          height: responsiveSize,
          child: Stack(
            alignment: Alignment.center,
            children: [
              CustomPaint(
                size: Size(responsiveSize, responsiveSize),
                painter: _GaugePainter(
                  score: currentScore,
                  color: color,
                  trackColor: AppColors.border,
                ),
              ),
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    currentScore.toInt().toString(),
                    style: AppTextStyles.display2.copyWith(
                      color: color,
                      fontSize: responsiveSize * 0.28,
                    ),
                  ),
                  if (widget.showLabel)
                    Text(
                      _gradeLabel(currentScore),
                      style: AppTextStyles.labelSmall.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

class _GaugePainter extends CustomPainter {
  final double score;
  final Color color;
  final Color trackColor;

  _GaugePainter({
    required this.score,
    required this.color,
    required this.trackColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width / 2) - 12;
    const strokeWidth = 10.0;
    const startAngle = math.pi * 0.75;
    const sweepAngle = math.pi * 1.5;

    // Track
    final trackPaint = Paint()
      ..color = trackColor
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      startAngle,
      sweepAngle,
      false,
      trackPaint,
    );

    // Progress
    final progressPaint = Paint()
      ..shader = SweepGradient(
        startAngle: startAngle,
        endAngle: startAngle + sweepAngle,
        colors: [color.withValues(alpha: 0.7), color],
        tileMode: TileMode.clamp,
      ).createShader(Rect.fromCircle(center: center, radius: radius))
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final progress = (score / 100).clamp(0.0, 1.0);
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      startAngle,
      sweepAngle * progress,
      false,
      progressPaint,
    );
  }

  @override
  bool shouldRepaint(_GaugePainter old) =>
      old.score != score || old.color != color;
}

// ─── Mini score badge (for trip cards) ────────────────────────────────────
class ScoreBadge extends StatelessWidget {
  final double score;
  final double size;

  const ScoreBadge({super.key, required this.score, this.size = 48});

  @override
  Widget build(BuildContext context) {
    final color = AppColors.scoreColor(score);
    final bgColor = AppColors.scoreColorLight(score);
    final responsiveSize = size.r;
    return Container(
      width: responsiveSize,
      height: responsiveSize,
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(responsiveSize * 0.3),
      ),
      child: Center(
        child: Text(
          score.toInt().toString(),
          style: AppTextStyles.h4.copyWith(color: color),
        ),
      ),
    );
  }
}

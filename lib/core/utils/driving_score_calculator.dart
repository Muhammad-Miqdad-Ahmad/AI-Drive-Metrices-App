import '../../models/models.dart';

/// Computes a [DriverScoreModel] entirely on the mobile device from a list
/// of [TripEvent]s.  No Supabase `driver_scores` table is needed.
///
/// ## Scoring philosophy
/// Each sub-score starts at 100 and is penalised by the severity of harsh
/// events, measured via `g_worst` (g-force magnitude).
///
/// ### g_worst severity tiers
/// | Tier     | g_worst range  | Per-event penalty |
/// |----------|---------------|-------------------|
/// | Mild     | 0.1 – 0.29 g  | −3 pts            |
/// | Moderate | 0.30 – 0.59 g | −8 pts            |
/// | Severe   | ≥ 0.60 g      | −18 pts           |
///
/// Each sub-score is clamped to [0, 100].
/// The overall score is the weighted average:
///   braking × 35% + cornering × 25% + acceleration × 25% + smoothness × 15%
class DrivingScoreCalculator {
  // ── Thresholds ─────────────────────────────────────────────────────────────
  static const double _mildThreshold = 0.1;
  static const double _moderateThreshold = 0.30;
  static const double _severeThreshold = 0.60;

  // ── Per-event deductions ───────────────────────────────────────────────────
  static const double _mildPenalty = 3.0;
  static const double _moderatePenalty = 8.0;
  static const double _severePenalty = 18.0;

  // ── Overall score weights (must sum to 1.0) ────────────────────────────────
  static const double _wBraking = 0.35;
  static const double _wCornering = 0.25;
  static const double _wAcceleration = 0.25;
  static const double _wSmoothness = 0.15;

  /// Returns a deduction amount based on [gWorst] severity tier.
  /// Returns 0 if [gWorst] is null, zero, or below the mild threshold
  /// (i.e. the event is within normal driving range).
  static double _penalty(double? gWorst) {
    if (gWorst == null || gWorst < _mildThreshold) return 0;
    if (gWorst < _moderateThreshold) return _mildPenalty;
    if (gWorst < _severeThreshold) return _moderatePenalty;
    return _severePenalty;
  }

  /// Compute a [DriverScoreModel] from [events].
  ///
  /// - Braking score    ← penalised by [TripEventType.harshBraking] events
  /// - Cornering score  ← penalised by left/right turn events
  /// - Acceleration score ← penalised by [TripEventType.hardAccel] events
  /// - Smoothness score ← penalised by *all* harsh events (composite)
  ///
  /// If [events] is empty the caller receives a perfect score of 100/A+
  /// (no data → no penalties).
  static DriverScoreModel compute(List<TripEvent> events) {
    double braking = 100;
    double cornering = 100;
    double acceleration = 100;
    double smoothness = 100;
    int harshCount = 0;

    for (final event in events) {
      if (!event.type.isHarsh) continue;

      harshCount++;
      final pen = _penalty(event.gWorst);

      switch (event.type) {
        case TripEventType.harshBraking:
          braking = (braking - pen).clamp(0, 100);
          smoothness = (smoothness - pen * 0.5).clamp(0, 100);
          break;
        case TripEventType.leftTurn:
        case TripEventType.rightTurn:
          cornering = (cornering - pen).clamp(0, 100);
          smoothness = (smoothness - pen * 0.4).clamp(0, 100);
          break;
        case TripEventType.hardAccel:
          acceleration = (acceleration - pen).clamp(0, 100);
          smoothness = (smoothness - pen * 0.4).clamp(0, 100);
          break;
        default:
          break;
      }
    }

    final overall = braking * _wBraking +
        cornering * _wCornering +
        acceleration * _wAcceleration +
        smoothness * _wSmoothness;

    return DriverScoreModel(
      overall: overall.clamp(0, 100),
      braking: braking,
      cornering: cornering,
      acceleration: acceleration,
      smoothness: smoothness,
      grade: DriverScoreModel.gradeFromScore(overall),
      harshEventCount: harshCount,
    );
  }

  /// Convenience: compute an aggregate [DriverScoreModel] across multiple trips
  /// by averaging each sub-score dimension.
  static DriverScoreModel aggregate(List<DriverScoreModel> scores) {
    if (scores.isEmpty) {
      return const DriverScoreModel(
        overall: 0,
        braking: 0,
        cornering: 0,
        acceleration: 0,
        smoothness: 0,
        grade: 'N/A',
      );
    }

    final n = scores.length.toDouble();
    final braking = scores.map((s) => s.braking).reduce((a, b) => a + b) / n;
    final cornering =
        scores.map((s) => s.cornering).reduce((a, b) => a + b) / n;
    final acceleration =
        scores.map((s) => s.acceleration).reduce((a, b) => a + b) / n;
    final smoothness =
        scores.map((s) => s.smoothness).reduce((a, b) => a + b) / n;
    final overall = scores.map((s) => s.overall).reduce((a, b) => a + b) / n;
    final harshCount =
        scores.map((s) => s.harshEventCount).reduce((a, b) => a + b);

    return DriverScoreModel(
      overall: overall,
      braking: braking,
      cornering: cornering,
      acceleration: acceleration,
      smoothness: smoothness,
      grade: DriverScoreModel.gradeFromScore(overall),
      harshEventCount: harshCount,
    );
  }
}

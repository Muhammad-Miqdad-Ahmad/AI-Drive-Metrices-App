import '../../models/models.dart';

/// Computes a [DriverScoreModel] entirely on the mobile device from a list
/// of [TripEvent]s.  No Supabase `driver_scores` table is needed.
///
/// ## Scoring philosophy
/// Each sub-score starts at 100 and is penalised by the severity of harsh
/// events, measured via `g_worst` (g-force magnitude).
///
/// ### IMPORTANT — Gravity baseline correction
/// The IMU reports the *resultant* g-force magnitude
/// (`sqrt(ax² + ay² + az²)`), which always includes ~1.0g of gravity plus
/// whatever tilt the device is mounted at. A stationary or smoothly-cruising
/// car therefore reads ~1.0–1.2g raw, NOT 0g. If we fed that raw value
/// straight into the severity tiers below, every single reading would land
/// in the "Severe" tier (≥0.60g) and the whole trip would score as
/// maximally harsh — which is wrong.
///
/// To fix this, [compute] subtracts a `baseline` g-value from every raw
/// `gWorst` reading before classifying it. The baseline represents "device
/// at rest" and should ideally be calibrated per-trip (e.g. averaging Gmax
/// over rows where Speed == 0), since mounting angle varies between
/// installs. If no calibration is available, a sane default of 1.0g is used.
///
/// ### Dynamic-g severity tiers (after baseline subtraction)
/// | Tier     | dynamic g range | Per-event penalty |
/// |----------|------------------|-------------------|
/// | Mild     | 0.1 – 0.29 g     | −3 pts            |
/// | Moderate | 0.30 – 0.59 g    | −8 pts            |
/// | Severe   | ≥ 0.60 g         | −18 pts           |
///
/// Each sub-score is clamped to [0, 100].
/// The overall score is the weighted average:
///   braking × 35% + cornering × 25% + acceleration × 25% + smoothness × 15%
class DrivingScoreCalculator {
  // ── Gravity baseline correction ────────────────────────────────────────────
  static const double defaultGravityBaseline = 1.0;

  // ── Thresholds (apply to *dynamic* g, i.e. after baseline subtraction) ────
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

  /// Strips the gravity/tilt baseline out of a raw resultant Gmax reading,
  /// returning only the "dynamic" component caused by braking, cornering,
  /// or acceleration.
  static double dynamicG(double gWorstRaw, double baseline) {
    final dynamic = gWorstRaw - baseline;
    return dynamic < 0 ? 0 : dynamic;
  }

  /// Returns a deduction amount based on [gWorstRaw] severity tier, after
  /// correcting for [baseline] gravity offset.
  static double _penalty(double? gWorstRaw, double baseline) {
    if (gWorstRaw == null) return 0;
    final gWorst = dynamicG(gWorstRaw, baseline);
    if (gWorst < _mildThreshold) return 0;
    if (gWorst < _moderateThreshold) return _mildPenalty;
    if (gWorst < _severeThreshold) return _moderatePenalty;
    return _severePenalty;
  }

  /// Estimates a resting/cruising g-force baseline directly from this trip's
  /// own events. Uses the lowest ~25% of readings as a proxy for "at rest".
  static double _estimateBaselineFromEvents(List<TripEvent> events) {
    final readings = events
        .map((e) => e.gWorst)
        .whereType<double>()
        .toList()
      ..sort();

    if (readings.isEmpty) return defaultGravityBaseline;

    final sampleCount = (readings.length * 0.25).ceil().clamp(1, readings.length);
    final lowest = readings.sublist(0, sampleCount);
    return lowest.reduce((a, b) => a + b) / lowest.length;
  }

  /// Compute a [DriverScoreModel] from [events].
  static DriverScoreModel compute(
    List<TripEvent> events, {
    double? calibratedBaseline,
  }) {
    if (events.isEmpty) {
      return const DriverScoreModel(
        overall: 100,
        braking: 100,
        cornering: 100,
        acceleration: 100,
        smoothness: 100,
        grade: 'A+',
        harshEventCount: 0,
      );
    }

    final baseline =
        calibratedBaseline ?? _estimateBaselineFromEvents(events);

    double braking = 100;
    double cornering = 100;
    double acceleration = 100;
    double smoothness = 100;
    int harshCount = 0;

    for (final event in events) {
      if (!event.type.isHarsh) continue;

      harshCount++;
      final pen = _penalty(event.gWorst, baseline);

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

  // ── Per-event score impact ─────────────────────────────────────────────────

  /// Returns a human-readable description of how much this single [event]
  /// penalised each affected sub-score category.
  ///
  /// Returns `null` for non-harsh events or events below the mild threshold.
  ///
  /// Examples:
  ///   harshBraking / Severe  → "−18 pts Braking · −9 pts Smoothness"
  ///   rightTurn   / Moderate → "−8 pts Cornering · −3.2 pts Smoothness"
  ///   hardAccel   / Mild     → "−3 pts Acceleration · −1.2 pts Smoothness"
  static EventScoreImpact? eventScoreImpact(
    TripEvent event, {
    double baseline = defaultGravityBaseline,
  }) {
    if (!event.type.isHarsh) return null;
    final pen = _penalty(event.gWorst, baseline);
    if (pen == 0) return null;

    switch (event.type) {
      case TripEventType.harshBraking:
        return EventScoreImpact(
          primary: _ScoreDelta('Braking', pen),
          secondary: _ScoreDelta('Smoothness', pen * 0.5),
        );
      case TripEventType.leftTurn:
      case TripEventType.rightTurn:
        return EventScoreImpact(
          primary: _ScoreDelta('Cornering', pen),
          secondary: _ScoreDelta('Smoothness', pen * 0.4),
        );
      case TripEventType.hardAccel:
        return EventScoreImpact(
          primary: _ScoreDelta('Acceleration', pen),
          secondary: _ScoreDelta('Smoothness', pen * 0.4),
        );
      default:
        return null;
    }
  }

  /// Tier label from raw g-force magnitude (not baseline-corrected).
  /// Used only for display purposes on the event card.
  static String penaltyLabel(double? gWorst,
      {double baseline = defaultGravityBaseline}) {
    final pen = _penalty(gWorst, baseline);
    if (pen == 0) return 'None';
    if (pen <= _mildPenalty) return 'Mild';
    if (pen <= _moderatePenalty) return 'Moderate';
    return 'Severe';
  }
}

/// Score deduction for one category caused by a single harsh event.
class _ScoreDelta {
  final String category;
  final double points;
  const _ScoreDelta(this.category, this.points);
}

/// The combined score impact (primary category + smoothness) for one event.
class EventScoreImpact {
  final _ScoreDelta primary;
  final _ScoreDelta secondary;

  const EventScoreImpact({required this.primary, required this.secondary});

  /// Short summary, e.g. "−18 pts Braking · −9 pts Smoothness"
  String get summary {
    final p = '−${_fmt(primary.points)} pts ${primary.category}';
    final s = '−${_fmt(secondary.points)} pts ${secondary.category}';
    return '$p  ·  $s';
  }

  String _fmt(double v) {
    if (v == v.truncateToDouble()) return v.toInt().toString();
    return v.toStringAsFixed(1);
  }
}
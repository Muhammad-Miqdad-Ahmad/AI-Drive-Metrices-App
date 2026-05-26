// models.dart
// Fully compatible with the existing mock_data_service.dart and all screens.
// Adds: BehaviourClass, SensorFrame, LiveTripState, classCounts on TripModel,
//       sourceClass/confidence on TripEvent, speedKmh on LatLngPoint.

// ─── Behaviour Class (6-class Random Forest output) ──────────────────────────
enum BehaviourClass {
  idle,         // 0
  normal,       // 1
  suddenAccel,  // 2
  rightTurn,    // 3
  leftTurn,     // 4
  suddenBrake,  // 5
}

extension BehaviourClassX on BehaviourClass {
  static BehaviourClass fromIndex(int i) =>
      BehaviourClass.values[i.clamp(0, 5)];

  String get label {
    switch (this) {
      case BehaviourClass.idle:        return 'Idle';
      case BehaviourClass.normal:      return 'Normal Driving';
      case BehaviourClass.suddenAccel: return 'Sudden Acceleration';
      case BehaviourClass.rightTurn:   return 'Sharp Right Turn';
      case BehaviourClass.leftTurn:    return 'Sharp Left Turn';
      case BehaviourClass.suddenBrake: return 'Sudden Brake';
    }
  }

  bool get isHarsh => index >= 2;

  TripEventType? get eventType {
    switch (this) {
      case BehaviourClass.suddenAccel: return TripEventType.hardAccel;
      case BehaviourClass.rightTurn:   return TripEventType.sharpTurn;
      case BehaviourClass.leftTurn:    return TripEventType.sharpTurn;
      case BehaviourClass.suddenBrake: return TripEventType.harshBraking;
      default:                         return null;
    }
  }
}

// ─── SensorFrame — one parsed BLE packet ─────────────────────────────────────
class SensorFrame {
  final int seqNo;
  final DateTime timestamp;
  final double ax, ay, az; // g-force
  final double gx, gy, gz; // deg/s
  final BehaviourClass detectedClass;
  final double confidence;
  final double? latitude;
  final double? longitude;
  final double? speedKmh;
  final bool gpsFix;

  const SensorFrame({
    required this.seqNo,
    required this.timestamp,
    required this.ax,
    required this.ay,
    required this.az,
    required this.gx,
    required this.gy,
    required this.gz,
    required this.detectedClass,
    required this.confidence,
    this.latitude,
    this.longitude,
    this.speedKmh,
    this.gpsFix = false,
  });

  factory SensorFrame.fromJson(Map<String, dynamic> j) => SensorFrame(
        seqNo: (j['seq'] as num).toInt(),
        timestamp: j['ts'] != null
            ? DateTime.fromMillisecondsSinceEpoch((j['ts'] as num).toInt())
            : DateTime.now(),
        ax: (j['ax'] as num).toDouble(),
        ay: (j['ay'] as num).toDouble(),
        az: (j['az'] as num).toDouble(),
        gx: (j['gx'] as num).toDouble(),
        gy: (j['gy'] as num).toDouble(),
        gz: (j['gz'] as num).toDouble(),
        detectedClass: BehaviourClassX.fromIndex((j['cls'] as num).toInt()),
        confidence: (j['conf'] as num).toDouble(),
        latitude:  j['lat'] != null ? (j['lat'] as num).toDouble() : null,
        longitude: j['lng'] != null ? (j['lng'] as num).toDouble() : null,
        speedKmh:  j['spd'] != null ? (j['spd'] as num).toDouble() : null,
        gpsFix: j['fix'] as bool? ?? false,
      );

  double get totalAccelG =>
      (ax * ax + ay * ay + az * az).clamp(0.0, 999.0);
}

// ─── UserModel ────────────────────────────────────────────────────────────────
class UserModel {
  final String id;
  final String fullName;
  final String email;
  final String? avatarUrl;
  final DateTime createdAt;

  const UserModel({
    required this.id,
    required this.fullName,
    required this.email,
    this.avatarUrl,
    required this.createdAt,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) => UserModel(
        id: json['id'] as String,
        fullName: json['full_name'] as String,
        email: json['email'] as String,
        avatarUrl: json['avatar_url'] as String?,
        createdAt: DateTime.parse(json['created_at'] as String),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'full_name': fullName,
        'email': email,
        'avatar_url': avatarUrl,
        'created_at': createdAt.toIso8601String(),
      };

  UserModel copyWith({String? fullName, String? email, String? avatarUrl}) =>
      UserModel(
        id: id,
        fullName: fullName ?? this.fullName,
        email: email ?? this.email,
        avatarUrl: avatarUrl ?? this.avatarUrl,
        createdAt: createdAt,
      );
}

// ─── DriverScoreModel ─────────────────────────────────────────────────────────
class DriverScoreModel {
  final double overall;
  final double braking;
  final double cornering;
  final double speeding;
  final double smoothness;
  final String grade;

  const DriverScoreModel({
    required this.overall,
    required this.braking,
    required this.cornering,
    required this.speeding,
    required this.smoothness,
    required this.grade,
  });

  static String gradeFromScore(double score) {
    if (score >= 90) return 'A+';
    if (score >= 80) return 'A';
    if (score >= 70) return 'B';
    if (score >= 60) return 'C';
    if (score >= 50) return 'D';
    return 'F';
  }

  factory DriverScoreModel.fromJson(Map<String, dynamic> json) =>
      DriverScoreModel(
        overall:    (json['overall']    as num).toDouble(),
        braking:    (json['braking']    as num).toDouble(),
        cornering:  (json['cornering']  as num).toDouble(),
        speeding:   (json['speeding']   as num).toDouble(),
        smoothness: (json['smoothness'] as num).toDouble(),
        grade: json['grade'] as String,
      );

  Map<String, dynamic> toJson() => {
        'overall':    overall,
        'braking':    braking,
        'cornering':  cornering,
        'speeding':   speeding,
        'smoothness': smoothness,
        'grade':      grade,
      };

  /// Compute a score dynamically from real trip data.
  static DriverScoreModel fromTrip({
    required List<TripEvent> events,
    required double distanceKm,
    required double maxSpeedKmh,
    required double avgSpeedKmh,
  }) {
    final brakeCount = events.where((e) => e.type == TripEventType.harshBraking).length;
    final turnCount  = events.where((e) => e.type == TripEventType.sharpTurn).length;
    final accelCount = events.where((e) => e.type == TripEventType.hardAccel).length;
    final totalPer10km = distanceKm > 0
        ? (events.length / distanceKm) * 10
        : 0.0;

    final braking    = (100 - (brakeCount * 12).clamp(0, 60)).toDouble();
    final cornering  = (100 - (turnCount  * 10).clamp(0, 50)).toDouble();
    final speedPen   = maxSpeedKmh > 120
        ? ((maxSpeedKmh - 120) * 0.8).clamp(0.0, 50.0)
        : 0.0;
    final speeding   = (100 - speedPen).toDouble();
    final smoothness = (100 - (totalPer10km * 8).clamp(0.0, 50.0)).toDouble();
    final overall    = (braking * 0.30 + cornering * 0.25 +
                        speeding * 0.25 + smoothness * 0.20)
        .clamp(0.0, 100.0);

    return DriverScoreModel(
      overall: overall, braking: braking, cornering: cornering,
      speeding: speeding, smoothness: smoothness,
      grade: gradeFromScore(overall),
    );
  }
}

// ─── TripEventType ────────────────────────────────────────────────────────────
enum TripEventType { harshBraking, sharpTurn, speeding, collision, hardAccel }

// ─── TripEvent ────────────────────────────────────────────────────────────────
// Backward-compatible: sourceClass and confidence are optional.
class TripEvent {
  final TripEventType type;
  final DateTime timestamp;
  final double? value;
  final double latitude;
  final double longitude;
  // ── new fields (optional so existing mock data compiles unchanged) ──
  final BehaviourClass? sourceClass;
  final double? confidence;

  const TripEvent({
    required this.type,
    required this.timestamp,
    this.value,
    required this.latitude,
    required this.longitude,
    this.sourceClass,   // ← optional, won't break existing callers
    this.confidence,    // ← optional
  });

  factory TripEvent.fromJson(Map<String, dynamic> json) => TripEvent(
        type:      TripEventType.values.byName(json['type'] as String),
        timestamp: DateTime.parse(json['timestamp'] as String),
        value:     json['value']     != null ? (json['value']     as num).toDouble() : null,
        latitude:  (json['latitude']  as num).toDouble(),
        longitude: (json['longitude'] as num).toDouble(),
        sourceClass: json['source_class'] != null
            ? BehaviourClassX.fromIndex((json['source_class'] as num).toInt())
            : null,
        confidence: json['confidence'] != null
            ? (json['confidence'] as num).toDouble()
            : null,
      );

  Map<String, dynamic> toJson() => {
        'type':         type.name,
        'timestamp':    timestamp.toIso8601String(),
        'value':        value,
        'latitude':     latitude,
        'longitude':    longitude,
        'source_class': sourceClass?.index,
        'confidence':   confidence,
      };

  String get label {
    switch (type) {
      case TripEventType.harshBraking: return 'Harsh Braking';
      case TripEventType.sharpTurn:    return 'Sharp Turn';
      case TripEventType.speeding:     return 'Speeding';
      case TripEventType.collision:    return 'Collision Detected';
      case TripEventType.hardAccel:    return 'Hard Acceleration';
    }
  }
}

// ─── LatLngPoint ──────────────────────────────────────────────────────────────
// Backward-compatible: added optional speedKmh and timestamp.
class LatLngPoint {
  final double latitude;
  final double longitude;
  final DateTime? timestamp;  // ← new, optional
  final double? speedKmh;     // ← new, optional

  const LatLngPoint({
    required this.latitude,
    required this.longitude,
    this.timestamp,
    this.speedKmh,
  });

  factory LatLngPoint.fromJson(Map<String, dynamic> json) => LatLngPoint(
        latitude:  (json['lat'] as num).toDouble(),
        longitude: (json['lng'] as num).toDouble(),
        timestamp: json['ts']  != null ? DateTime.parse(json['ts'] as String) : null,
        speedKmh:  json['spd'] != null ? (json['spd'] as num).toDouble()      : null,
      );

  Map<String, dynamic> toJson() => {
        'lat': latitude,
        'lng': longitude,
        'ts':  timestamp?.toIso8601String(),
        'spd': speedKmh,
      };
}

// ─── TripModel ────────────────────────────────────────────────────────────────
// Backward-compatible: classCounts is optional (defaults to empty map).
class TripModel {
  final String id;
  final DateTime startTime;
  final DateTime? endTime;
  final double distanceKm;
  final double maxSpeedKmh;
  final double avgSpeedKmh;
  final DriverScoreModel score;
  final List<TripEvent> events;
  final List<LatLngPoint> route;
  final bool isActive;
  // ── new field ──
  final Map<BehaviourClass, int> classCounts;

  const TripModel({
    required this.id,
    required this.startTime,
    this.endTime,
    required this.distanceKm,
    required this.maxSpeedKmh,
    required this.avgSpeedKmh,
    required this.score,
    required this.events,
    required this.route,
    this.isActive = false,
    this.classCounts = const {},   // ← optional, existing callers unaffected
  });

  Duration get duration {
    final end = endTime ?? DateTime.now();
    return end.difference(startTime);
  }

  String get durationLabel {
    final d = duration;
    if (d.inHours > 0) {
      return '${d.inHours}h ${d.inMinutes.remainder(60)}m';
    }
    return '${d.inMinutes}m';
  }

  int get harshBrakingCount =>
      events.where((e) => e.type == TripEventType.harshBraking).length;
  int get sharpTurnCount =>
      events.where((e) => e.type == TripEventType.sharpTurn).length;
  int get hardAccelCount =>
      events.where((e) => e.type == TripEventType.hardAccel).length;
  int get speedingCount =>
      events.where((e) => e.type == TripEventType.speeding).length;

  factory TripModel.fromJson(Map<String, dynamic> json) => TripModel(
        id:          json['id'] as String,
        startTime:   DateTime.parse(json['start_time'] as String),
        endTime:     json['end_time'] != null
            ? DateTime.parse(json['end_time'] as String)
            : null,
        distanceKm:  (json['distance_km']  as num).toDouble(),
        maxSpeedKmh: (json['max_speed_kmh'] as num).toDouble(),
        avgSpeedKmh: (json['avg_speed_kmh'] as num).toDouble(),
        score: DriverScoreModel.fromJson(json['score'] as Map<String, dynamic>),
        events: (json['events'] as List)
            .map((e) => TripEvent.fromJson(e as Map<String, dynamic>))
            .toList(),
        route: (json['route'] as List)
            .map((p) => LatLngPoint.fromJson(p as Map<String, dynamic>))
            .toList(),
        isActive: json['is_active'] as bool? ?? false,
        classCounts: (json['class_counts'] as Map<String, dynamic>?)
                ?.map((k, v) => MapEntry(
                    BehaviourClassX.fromIndex(int.parse(k)),
                    (v as num).toInt())) ??
            {},
      );

  Map<String, dynamic> toJson() => {
        'id':            id,
        'start_time':    startTime.toIso8601String(),
        'end_time':      endTime?.toIso8601String(),
        'distance_km':   distanceKm,
        'max_speed_kmh': maxSpeedKmh,
        'avg_speed_kmh': avgSpeedKmh,
        'score':         score.toJson(),
        'events':        events.map((e) => e.toJson()).toList(),
        'route':         route.map((p) => p.toJson()).toList(),
        'is_active':     isActive,
        'class_counts':  classCounts.map((k, v) => MapEntry(k.index.toString(), v)),
      };
}

// ─── LiveTripState ────────────────────────────────────────────────────────────
class LiveTripState {
  final String tripId;
  final DateTime startTime;
  final List<TripEvent> events;
  final List<LatLngPoint> route;
  final Map<BehaviourClass, int> classCounts;
  double distanceKm;
  double maxSpeedKmh;
  double _speedSum;
  int _speedSamples;

  LiveTripState({required this.tripId, required this.startTime})
      : events = [],
        route = [],
        classCounts = {},
        distanceKm = 0,
        maxSpeedKmh = 0,
        _speedSum = 0,
        _speedSamples = 0;

  double get avgSpeedKmh =>
      _speedSamples > 0 ? _speedSum / _speedSamples : 0;

  void addFrame(SensorFrame frame) {
    // Count class
    classCounts[frame.detectedClass] =
        (classCounts[frame.detectedClass] ?? 0) + 1;

    // GPS
    if (frame.gpsFix && frame.latitude != null && frame.longitude != null) {
      final pt = LatLngPoint(
        latitude: frame.latitude!,
        longitude: frame.longitude!,
        timestamp: frame.timestamp,
        speedKmh: frame.speedKmh,
      );
      if (route.isNotEmpty) {
        distanceKm += _haversineKm(
          route.last.latitude, route.last.longitude,
          pt.latitude, pt.longitude,
        );
      }
      route.add(pt);
    }

    // Speed
    if (frame.speedKmh != null) {
      if (frame.speedKmh! > maxSpeedKmh) maxSpeedKmh = frame.speedKmh!;
      _speedSum += frame.speedKmh!;
      _speedSamples++;
    }

    // Harsh events — only log if confidence >= 0.60
    if (frame.detectedClass.isHarsh && frame.confidence >= 0.60) {
      final eventType = frame.detectedClass.eventType;
      if (eventType != null) {
        events.add(TripEvent(
          type: eventType,
          timestamp: frame.timestamp,
          value: frame.totalAccelG,
          latitude:  frame.latitude  ?? 0,
          longitude: frame.longitude ?? 0,
          sourceClass: frame.detectedClass,
          confidence: frame.confidence,
        ));
      }
    }
  }

  TripModel toTripModel() {
    final score = DriverScoreModel.fromTrip(
      events: events,
      distanceKm: distanceKm,
      maxSpeedKmh: maxSpeedKmh,
      avgSpeedKmh: avgSpeedKmh,
    );
    return TripModel(
      id: tripId,
      startTime: startTime,
      endTime: DateTime.now(),
      distanceKm: distanceKm,
      maxSpeedKmh: maxSpeedKmh,
      avgSpeedKmh: avgSpeedKmh,
      score: score,
      events: List.unmodifiable(events),
      route: List.unmodifiable(route),
      isActive: false,
      classCounts: Map.unmodifiable(classCounts),
    );
  }

  static double _haversineKm(
      double lat1, double lon1, double lat2, double lon2) {
    const r = 6371.0;
    final dLat = _rad(lat2 - lat1);
    final dLon = _rad(lon2 - lon1);
    final a = _sin2(dLat / 2) +
        _cos(_rad(lat1)) * _cos(_rad(lat2)) * _sin2(dLon / 2);
    return r * 2 * _asin(_sqrt(a.clamp(0.0, 1.0)));
  }

  static double _rad(double d) => d * 3.141592653589793 / 180;
  static double _sin2(double x) { final s = _sinA(x); return s * s; }
  static double _cos(double x)  => _sinA(x + 1.5707963267948966);
  static double _asin(double x) => x + (x * x * x) / 6.0;
  static double _sqrt(double x) {
    if (x <= 0) return 0;
    double g = x / 2;
    for (int i = 0; i < 6; i++) g = (g + x / g) / 2;
    return g;
  }
  static double _sinA(double x) {
    // Reduce to [-π, π]
    const pi = 3.141592653589793;
    x = x % (2 * pi);
    if (x > pi)  x -= 2 * pi;
    if (x < -pi) x += 2 * pi;
    return x - (x*x*x)/6 + (x*x*x*x*x)/120 - (x*x*x*x*x*x*x)/5040;
  }
}

// ─── VehicleHealthModel ───────────────────────────────────────────────────────
class VehicleHealthModel {
  final double overall;
  final double engineHealth;
  final double brakeWear;
  final double suspensionStress;
  final double tyrePressureScore;
  final DateTime lastUpdated;
  final List<HealthInsight> insights;

  const VehicleHealthModel({
    required this.overall,
    required this.engineHealth,
    required this.brakeWear,
    required this.suspensionStress,
    required this.tyrePressureScore,
    required this.lastUpdated,
    required this.insights,
  });

  factory VehicleHealthModel.fromJson(Map<String, dynamic> json) =>
      VehicleHealthModel(
        overall:           (json['overall']            as num).toDouble(),
        engineHealth:      (json['engine_health']       as num).toDouble(),
        brakeWear:         (json['brake_wear']          as num).toDouble(),
        suspensionStress:  (json['suspension_stress']   as num).toDouble(),
        tyrePressureScore: (json['tyre_pressure_score'] as num).toDouble(),
        lastUpdated: DateTime.parse(json['last_updated'] as String),
        insights: (json['insights'] as List)
            .map((i) => HealthInsight.fromJson(i as Map<String, dynamic>))
            .toList(),
      );

  Map<String, dynamic> toJson() => {
        'overall':             overall,
        'engine_health':       engineHealth,
        'brake_wear':          brakeWear,
        'suspension_stress':   suspensionStress,
        'tyre_pressure_score': tyrePressureScore,
        'last_updated':        lastUpdated.toIso8601String(),
        'insights':            insights.map((i) => i.toJson()).toList(),
      };

  /// Compute health from accumulated trip history (used by TripRepository).
  static VehicleHealthModel fromTripHistory(List<TripModel> trips) {
    if (trips.isEmpty) {
      return VehicleHealthModel(
        overall: 100, engineHealth: 100, brakeWear: 100,
        suspensionStress: 100, tyrePressureScore: 100,
        lastUpdated: DateTime.now(), insights: [],
      );
    }
    final totalBrakes = trips.fold(0, (s, t) => s + t.harshBrakingCount);
    final totalTurns  = trips.fold(0, (s, t) => s + t.sharpTurnCount);
    final totalAccel  = trips.fold(0, (s, t) => s + t.hardAccelCount);
    final totalKm     = trips.fold(0.0, (s, t) => s + t.distanceKm);

    final brakeWear  = (100 - (totalBrakes * 2.5 + totalKm * 0.02).clamp(0, 60)).toDouble();
    final suspension = (100 - (totalTurns  * 1.5).clamp(0, 40)).toDouble();
    final engine     = (100 - (totalAccel  * 1.0).clamp(0, 30)).toDouble();
    final tyre       = (100 - (totalKm     * 0.03).clamp(0, 30)).toDouble();
    final overall    = (brakeWear * 0.30 + suspension * 0.25 +
                        engine * 0.25 + tyre * 0.20).clamp(0.0, 100.0);

    final insights = <HealthInsight>[];
    if (brakeWear < 70) {
      insights.add(HealthInsight(
        title: 'Brake Wear Detected',
        description:
            '$totalBrakes harsh braking events detected. Consider inspection within 2,000 km.',
        severity: brakeWear < 50 ? 'warning' : 'info',
      ));
    }
    if (suspension < 80) {
      insights.add(HealthInsight(
        title: 'Suspension Stress',
        description:
            '$totalTurns sharp turn events detected. High lateral G-forces may stress suspension.',
        severity: 'info',
      ));
    }
    insights.add(HealthInsight(
      title: engine >= 80 ? 'Engine Health Good' : 'Engine Load Elevated',
      description: engine >= 80
          ? 'No anomalies detected in engine-related metrics.'
          : '$totalAccel hard acceleration events logged.',
      severity: engine >= 80 ? 'info' : 'warning',
    ));

    return VehicleHealthModel(
      overall: overall, engineHealth: engine, brakeWear: brakeWear,
      suspensionStress: suspension, tyrePressureScore: tyre,
      lastUpdated: DateTime.now(), insights: insights,
    );
  }
}

class HealthInsight {
  final String title;
  final String description;
  final String severity; // 'info' | 'warning' | 'critical'

  const HealthInsight({
    required this.title,
    required this.description,
    required this.severity,
  });

  factory HealthInsight.fromJson(Map<String, dynamic> json) => HealthInsight(
        title:       json['title']       as String,
        description: json['description'] as String,
        severity:    json['severity']    as String,
      );

  Map<String, dynamic> toJson() => {
        'title':       title,
        'description': description,
        'severity':    severity,
      };
}
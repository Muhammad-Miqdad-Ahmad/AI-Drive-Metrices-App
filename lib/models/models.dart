// ─── User Model ────────────────────────────────────────────────────────────
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

  UserModel copyWith({
    String? fullName,
    String? email,
    String? avatarUrl,
  }) =>
      UserModel(
        id: id,
        fullName: fullName ?? this.fullName,
        email: email ?? this.email,
        avatarUrl: avatarUrl ?? this.avatarUrl,
        createdAt: createdAt,
      );
}

// ─── Driver Score Model ────────────────────────────────────────────────────
class DriverScoreModel {
  final double overall;        // 0–100
  final double braking;
  final double cornering;
  final double speeding;
  final double smoothness;
  final String grade;          // A, B, C, D, F

  const DriverScoreModel({
    required this.overall,
    required this.braking,
    required this.cornering,
    required this.speeding,
    required this.smoothness,
    required this.grade,
  });

  factory DriverScoreModel.fromJson(Map<String, dynamic> json) =>
      DriverScoreModel(
        overall: (json['overall'] as num).toDouble(),
        braking: (json['braking'] as num).toDouble(),
        cornering: (json['cornering'] as num).toDouble(),
        speeding: (json['speeding'] as num).toDouble(),
        smoothness: (json['smoothness'] as num).toDouble(),
        grade: json['grade'] as String,
      );

  Map<String, dynamic> toJson() => {
        'overall': overall,
        'braking': braking,
        'cornering': cornering,
        'speeding': speeding,
        'smoothness': smoothness,
        'grade': grade,
      };

  /// Compute grade from overall score
  static String gradeFromScore(double score) {
    if (score >= 90) return 'A+';
    if (score >= 80) return 'A';
    if (score >= 70) return 'B';
    if (score >= 60) return 'C';
    if (score >= 50) return 'D';
    return 'F';
  }
}

// ─── Trip Event Model ──────────────────────────────────────────────────────
enum TripEventType { harshBraking, sharpTurn, speeding, collision, hardAccel }

class TripEvent {
  final TripEventType type;
  final DateTime timestamp;
  final double? value;        // e.g. deceleration g-force, speed in km/h
  final double latitude;
  final double longitude;

  const TripEvent({
    required this.type,
    required this.timestamp,
    this.value,
    required this.latitude,
    required this.longitude,
  });

  factory TripEvent.fromJson(Map<String, dynamic> json) => TripEvent(
        type: TripEventType.values.byName(json['type'] as String),
        timestamp: DateTime.parse(json['timestamp'] as String),
        value: json['value'] != null ? (json['value'] as num).toDouble() : null,
        latitude: (json['latitude'] as num).toDouble(),
        longitude: (json['longitude'] as num).toDouble(),
      );

  Map<String, dynamic> toJson() => {
        'type': type.name,
        'timestamp': timestamp.toIso8601String(),
        'value': value,
        'latitude': latitude,
        'longitude': longitude,
      };

  String get label {
    switch (type) {
      case TripEventType.harshBraking:
        return 'Harsh Braking';
      case TripEventType.sharpTurn:
        return 'Sharp Turn';
      case TripEventType.speeding:
        return 'Speeding';
      case TripEventType.collision:
        return 'Collision Detected';
      case TripEventType.hardAccel:
        return 'Hard Acceleration';
    }
  }
}

// ─── Trip Model ────────────────────────────────────────────────────────────
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
  int get speedingCount =>
      events.where((e) => e.type == TripEventType.speeding).length;

  factory TripModel.fromJson(Map<String, dynamic> json) => TripModel(
        id: json['id'] as String,
        startTime: DateTime.parse(json['start_time'] as String),
        endTime: json['end_time'] != null
            ? DateTime.parse(json['end_time'] as String)
            : null,
        distanceKm: (json['distance_km'] as num).toDouble(),
        maxSpeedKmh: (json['max_speed_kmh'] as num).toDouble(),
        avgSpeedKmh: (json['avg_speed_kmh'] as num).toDouble(),
        score: DriverScoreModel.fromJson(
            json['score'] as Map<String, dynamic>),
        events: (json['events'] as List)
            .map((e) => TripEvent.fromJson(e as Map<String, dynamic>))
            .toList(),
        route: (json['route'] as List)
            .map((p) => LatLngPoint.fromJson(p as Map<String, dynamic>))
            .toList(),
        isActive: json['is_active'] as bool? ?? false,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'start_time': startTime.toIso8601String(),
        'end_time': endTime?.toIso8601String(),
        'distance_km': distanceKm,
        'max_speed_kmh': maxSpeedKmh,
        'avg_speed_kmh': avgSpeedKmh,
        'score': score.toJson(),
        'events': events.map((e) => e.toJson()).toList(),
        'route': route.map((p) => p.toJson()).toList(),
        'is_active': isActive,
      };
}

// ─── LatLngPoint ──────────────────────────────────────────────────────────
class LatLngPoint {
  final double latitude;
  final double longitude;
  final DateTime? timestamp;

  const LatLngPoint({
    required this.latitude,
    required this.longitude,
    this.timestamp,
  });

  factory LatLngPoint.fromJson(Map<String, dynamic> json) => LatLngPoint(
        latitude: (json['lat'] as num).toDouble(),
        longitude: (json['lng'] as num).toDouble(),
        timestamp: json['ts'] != null
            ? DateTime.parse(json['ts'] as String)
            : null,
      );

  Map<String, dynamic> toJson() => {
        'lat': latitude,
        'lng': longitude,
        'ts': timestamp?.toIso8601String(),
      };
}

// ─── Vehicle Health Model ─────────────────────────────────────────────────
class VehicleHealthModel {
  final double overall;         // 0–100
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
        overall: (json['overall'] as num).toDouble(),
        engineHealth: (json['engine_health'] as num).toDouble(),
        brakeWear: (json['brake_wear'] as num).toDouble(),
        suspensionStress: (json['suspension_stress'] as num).toDouble(),
        tyrePressureScore: (json['tyre_pressure_score'] as num).toDouble(),
        lastUpdated: DateTime.parse(json['last_updated'] as String),
        insights: (json['insights'] as List)
            .map((i) => HealthInsight.fromJson(i as Map<String, dynamic>))
            .toList(),
      );

  Map<String, dynamic> toJson() => {
        'overall': overall,
        'engine_health': engineHealth,
        'brake_wear': brakeWear,
        'suspension_stress': suspensionStress,
        'tyre_pressure_score': tyrePressureScore,
        'last_updated': lastUpdated.toIso8601String(),
        'insights': insights.map((i) => i.toJson()).toList(),
      };
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
        title: json['title'] as String,
        description: json['description'] as String,
        severity: json['severity'] as String,
      );

  Map<String, dynamic> toJson() => {
        'title': title,
        'description': description,
        'severity': severity,
      };
}

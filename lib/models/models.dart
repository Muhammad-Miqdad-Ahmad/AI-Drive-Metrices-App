import 'package:flutter/material.dart';
import 'dart:ui';

// ─── User Model ────────────────────────────────────────────────────────────
class UserModel {
  final String id;
  final String fullName;
  final String email;
  final String? avatarUrl;
  final String? deviceId;
  final DateTime createdAt;

  const UserModel({
    required this.id,
    required this.fullName,
    required this.email,
    this.avatarUrl,
    this.deviceId,
    required this.createdAt,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) => UserModel(
        id: json['id'] as String,
        fullName: json['full_name'] as String,
        email: json['email'] as String,
        avatarUrl: json['avatar_url'] as String?,
        deviceId: json['device_id'] as String?,
        createdAt: DateTime.parse(json['created_at'] as String),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'full_name': fullName,
        'email': email,
        'avatar_url': avatarUrl,
        'device_id': deviceId,
        'created_at': createdAt.toIso8601String(),
      };

  UserModel copyWith({
    String? fullName,
    String? email,
    String? avatarUrl,
    String? deviceId,
  }) =>
      UserModel(
        id: id,
        fullName: fullName ?? this.fullName,
        email: email ?? this.email,
        avatarUrl: avatarUrl ?? this.avatarUrl,
        deviceId: deviceId ?? this.deviceId,
        createdAt: createdAt,
      );
}

// ─── Driver Score Model ────────────────────────────────────────────────────
class DriverScoreModel {
  final double overall;
  final double braking;
  final double cornering;
  final double acceleration;
  final double smoothness;
  final String grade;
  final int harshEventCount;

  const DriverScoreModel({
    required this.overall,
    required this.braking,
    required this.cornering,
    required this.acceleration,
    required this.smoothness,
    required this.grade,
    this.harshEventCount = 0,
  });

  double get speeding => acceleration;

  factory DriverScoreModel.fromSupabase(Map<String, dynamic> json) =>
      DriverScoreModel(
        overall: (json['overall'] as num?)?.toDouble() ?? 0,
        braking: (json['braking'] as num?)?.toDouble() ?? 0,
        cornering: (json['cornering'] as num?)?.toDouble() ?? 0,
        acceleration: (json['acceleration'] as num?)?.toDouble() ?? 0,
        smoothness: (json['smoothness'] as num?)?.toDouble() ?? 0,
        grade: (json['grade'] as String?) ??
            gradeFromScore((json['overall'] as num?)?.toDouble() ?? 0),
        harshEventCount: (json['harsh_event_count'] as int?) ?? 0,
      );

  factory DriverScoreModel.fromJson(Map<String, dynamic> json) =>
      DriverScoreModel(
        overall: (json['overall'] as num).toDouble(),
        braking: (json['braking'] as num).toDouble(),
        cornering: (json['cornering'] as num).toDouble(),
        acceleration:
            (json['acceleration'] as num? ?? json['speeding'] as num?)
                    ?.toDouble() ??
                0,
        smoothness: (json['smoothness'] as num).toDouble(),
        grade: json['grade'] as String,
        harshEventCount: (json['harsh_event_count'] as int?) ?? 0,
      );

  Map<String, dynamic> toJson() => {
        'overall': overall,
        'braking': braking,
        'cornering': cornering,
        'acceleration': acceleration,
        'smoothness': smoothness,
        'grade': grade,
        'harsh_event_count': harshEventCount,
      };

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
enum TripEventType { idle, normalDriving, hardAccel, rightTurn, leftTurn, harshBraking }

extension TripEventTypeX on TripEventType {
  String get label {
    switch (this) {
      case TripEventType.idle:          return 'Idle';
      case TripEventType.normalDriving: return 'Normal Driving';
      case TripEventType.hardAccel:     return 'Hard Acceleration';
      case TripEventType.rightTurn:     return 'Right Turn';
      case TripEventType.leftTurn:      return 'Left Turn';
      case TripEventType.harshBraking:  return 'Harsh Braking';
    }
  }

  bool get isHarsh => index >= 2;
}

class TripEvent {
  final String id;
  final TripEventType type;
  final DateTime timestamp;
  final double confidence;
  final double latitude;
  final double longitude;
  final double? speedKmh;
  final double? accelX;
  final double? accelY;
  final double? accelZ;
  final double? gWorst;

  const TripEvent({
    required this.id,
    required this.type,
    required this.timestamp,
    required this.confidence,
    required this.latitude,
    required this.longitude,
    this.speedKmh,
    this.accelX,
    this.accelY,
    this.accelZ,
    this.gWorst,
  });

  factory TripEvent.fromSupabase(Map<String, dynamic> json) {
    final label = (json['event_label'] as int?) ?? 1;
    return TripEvent(
      id: json['id'] as String,
      type: TripEventType.values[label.clamp(0, TripEventType.values.length - 1)],
      timestamp: DateTime.parse(json['recorded_at'] as String),
      confidence: (json['confidence'] as num?)?.toDouble() ?? 0,
      latitude: (json['latitude'] as num?)?.toDouble() ?? 0,
      longitude: (json['longitude'] as num?)?.toDouble() ?? 0,
      speedKmh: (json['speed_kmh'] as num?)?.toDouble(),
      accelX: (json['accel_x'] as num?)?.toDouble(),
      accelY: (json['accel_y'] as num?)?.toDouble(),
      accelZ: (json['accel_z'] as num?)?.toDouble(),
      gWorst: (json['g_worst'] as num?)?.toDouble(),
    );
  }

  String get label => type.label;

  /// Severity label based on g_worst value (g-force).
  /// Mild < 0.3g | Moderate 0.3–0.6g | Severe >= 0.6g
  String? get harshnessLabel {
    if (gWorst == null || gWorst! <= 0) return null;
    if (gWorst! < 0.3) return 'Mild';
    if (gWorst! < 0.6) return 'Moderate';
    return 'Severe';
  }

  /// Color-coded by severity. Falls back to [defaultColor] if no gWorst data.
  Color harshnessColor(Color defaultColor) {
    if (gWorst == null || gWorst! <= 0) return defaultColor;
    if (gWorst! < 0.3) return const Color(0xFFF59E0B); // amber  – Mild
    if (gWorst! < 0.6) return const Color(0xFFF97316); // orange – Moderate
    return const Color(0xFFEF4444);                     // red    – Severe
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

  const TripModel({
    required this.id,
    required this.startTime,
    this.endTime,
    required this.distanceKm,
    required this.maxSpeedKmh,
    required this.avgSpeedKmh,
    required this.score,
    this.events = const [],
    this.route = const [],
  });

  Duration get duration {
    final end = endTime ?? DateTime.now();
    return end.difference(startTime);
  }

  String get durationLabel {
    final d = duration;
    if (d.inHours > 0) return '${d.inHours}h ${d.inMinutes.remainder(60)}m';
    return '${d.inMinutes}m';
  }

  int get harshEventCount => events.where((e) => e.type.isHarsh).length;

  /// Highest g_worst value across all harsh events in this trip.
  double? get worstGForce {
    final values = events
        .where((e) => e.type.isHarsh && e.gWorst != null && e.gWorst! > 0)
        .map((e) => e.gWorst!)
        .toList();
    if (values.isEmpty) return null;
    values.sort();
    return values.last;
  }

  /// Human-readable severity label for the worst g-force event.
  String? get worstHarshnessLabel {
    final g = worstGForce;
    if (g == null) return null;
    if (g < 0.3) return 'Mild';
    if (g < 0.6) return 'Moderate';
    return 'Severe';
  }
  int get harshBrakingCount =>
      events.where((e) => e.type == TripEventType.harshBraking).length;
  int get sharpTurnCount => events
      .where((e) =>
          e.type == TripEventType.leftTurn || e.type == TripEventType.rightTurn)
      .length;
  int get hardAccelCount =>
      events.where((e) => e.type == TripEventType.hardAccel).length;

  factory TripModel.fromSupabase(
    Map<String, dynamic> json, {
    List<TripEvent>? events,
    List<LatLngPoint>? route,
  }) {
    final scoreJson = json['driver_scores'];
    final score = scoreJson != null
        ? DriverScoreModel.fromSupabase(
            scoreJson is List
                ? scoreJson.first as Map<String, dynamic>
                : scoreJson as Map<String, dynamic>,
          )
        : const DriverScoreModel(
            overall: 0,
            braking: 0,
            cornering: 0,
            acceleration: 0,
            smoothness: 0,
            grade: 'N/A',
          );

    return TripModel(
      id: json['id'] as String,
      startTime: DateTime.parse(json['start_time'] as String),
      endTime: json['end_time'] != null
          ? DateTime.parse(json['end_time'] as String)
          : null,
      distanceKm: (json['distance_km'] as num?)?.toDouble() ?? 0,
      maxSpeedKmh: (json['max_speed_kmh'] as num?)?.toDouble() ?? 0,
      avgSpeedKmh: (json['avg_speed_kmh'] as num?)?.toDouble() ?? 0,
      score: score,
      events: events ?? [],
      route: route ?? [],
    );
  }
}

// ─── LatLngPoint ──────────────────────────────────────────────────────────
class LatLngPoint {
  final double latitude;
  final double longitude;
  final double? speedKmh;
  final DateTime? timestamp;

  const LatLngPoint({
    required this.latitude,
    required this.longitude,
    this.speedKmh,
    this.timestamp,
  });

  factory LatLngPoint.fromSupabase(Map<String, dynamic> json) => LatLngPoint(
        latitude: (json['latitude'] as num).toDouble(),
        longitude: (json['longitude'] as num).toDouble(),
        speedKmh: (json['speed_kmh'] as num?)?.toDouble(),
        timestamp: json['recorded_at'] != null
            ? DateTime.parse(json['recorded_at'] as String)
            : null,
      );

  factory LatLngPoint.fromJson(Map<String, dynamic> json) => LatLngPoint(
        latitude: (json['lat'] as num).toDouble(),
        longitude: (json['lng'] as num).toDouble(),
        speedKmh: (json['speed_kmh'] as num?)?.toDouble(),
        timestamp:
            json['ts'] != null ? DateTime.parse(json['ts'] as String) : null,
      );

  Map<String, dynamic> toJson() => {
        'lat': latitude,
        'lng': longitude,
        'speed_kmh': speedKmh,
        'ts': timestamp?.toIso8601String(),
      };
}

// ─── Vehicle Health Model ─────────────────────────────────────────────────
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
}

class HealthInsight {
  final String title;
  final String description;
  final String severity;

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

// ─── Device Reading Model (from ThingSpeak via Supabase) ──────────────────
class DeviceReading {
  final String id;
  final String prediction;
  final double confidence;
  final double speedKmh;
  final double latitude;
  final double longitude;
  final double gWorst;
  final DateTime recordedAt;

  const DeviceReading({
    required this.id,
    required this.prediction,
    required this.confidence,
    required this.speedKmh,
    required this.latitude,
    required this.longitude,
    required this.gWorst,
    required this.recordedAt,
  });

  factory DeviceReading.fromSupabase(Map<String, dynamic> json) =>
      DeviceReading(
        id: json['id'] as String,
        prediction: (json['prediction'] as String?) ?? 'Unknown',
        confidence: (json['confidence'] as num?)?.toDouble() ?? 0,
        speedKmh: (json['speed_kmh'] as num?)?.toDouble() ?? 0,
        latitude: (json['latitude'] as num?)?.toDouble() ?? 0,
        longitude: (json['longitude'] as num?)?.toDouble() ?? 0,
        gWorst: (json['g_worst'] as num?)?.toDouble() ?? 0,
        recordedAt: DateTime.parse(json['recorded_at'] as String),
      );
}
import 'dart:convert';
import 'package:flutter/foundation.dart';
import '../../models/models.dart';

// ─────────────────────────────────────────────────────────────────────────────
// TripRepository
//
// Local persistence layer for completed trips.
//
// Storage backend: sqflite  (add to pubspec.yaml)
//   dependencies:
//     sqflite: ^2.3.2
//     path: ^1.9.0
//
// The repository exposes a ChangeNotifier so UI can rebuild reactively
// when trips are added or deleted.
//
// NOTE: The sqflite calls below are written as comments showing the real
// implementation. An in-memory list is used as a stub so the app compiles
// without sqflite during UI development. Replace with the real DB calls
// once the package is added.
// ─────────────────────────────────────────────────────────────────────────────

class TripRepository extends ChangeNotifier {
  // In-memory store (stub) — replace with DB-backed list when sqflite is added.
  final List<TripModel> _trips = [];

  List<TripModel> get trips => List.unmodifiable(
        _trips.toList()..sort((a, b) => b.startTime.compareTo(a.startTime)),
      );

  bool _initialised = false;

  // ─────────────────────────────────────────────────────────────────────────
  // Initialisation
  // ─────────────────────────────────────────────────────────────────────────

  Future<void> init() async {
    if (_initialised) return;
    _initialised = true;

    // ── REAL IMPLEMENTATION ──────────────────────────────────────────────
    // final dbPath = join(await getDatabasesPath(), 'drive_metrics.db');
    // _db = await openDatabase(
    //   dbPath,
    //   version: 1,
    //   onCreate: (db, version) async {
    //     await db.execute('''
    //       CREATE TABLE trips (
    //         id        TEXT PRIMARY KEY,
    //         json_blob TEXT NOT NULL
    //       )
    //     ''');
    //   },
    // );
    // final rows = await _db!.query('trips', orderBy: 'json_extract(json_blob, "$.start_time") DESC');
    // _trips.addAll(rows.map((r) => TripModel.fromJson(jsonDecode(r['json_blob'] as String))));
    // ── END REAL IMPLEMENTATION ──────────────────────────────────────────

    // Seed with mock data so UI works before hardware is ready.
    _trips.addAll(_mockTrips());
    notifyListeners();
  }

  // ─────────────────────────────────────────────────────────────────────────
  // CRUD
  // ─────────────────────────────────────────────────────────────────────────

  Future<void> saveTrip(TripModel trip) async {
    final existing = _trips.indexWhere((t) => t.id == trip.id);
    if (existing >= 0) {
      _trips[existing] = trip;
    } else {
      _trips.add(trip);
    }

    // ── REAL IMPLEMENTATION ──────────────────────────────────────────────
    // await _db!.insert(
    //   'trips',
    //   {'id': trip.id, 'json_blob': jsonEncode(trip.toJson())},
    //   conflictAlgorithm: ConflictAlgorithm.replace,
    // );
    // ── END REAL IMPLEMENTATION ──────────────────────────────────────────

    notifyListeners();
  }

  Future<void> deleteTrip(String tripId) async {
    _trips.removeWhere((t) => t.id == tripId);

    // ── REAL IMPLEMENTATION ──────────────────────────────────────────────
    // await _db!.delete('trips', where: 'id = ?', whereArgs: [tripId]);
    // ── END REAL IMPLEMENTATION ──────────────────────────────────────────

    notifyListeners();
  }

  TripModel? getTrip(String tripId) {
    try {
      return _trips.firstWhere((t) => t.id == tripId);
    } catch (_) {
      return null;
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Derived statistics
  // ─────────────────────────────────────────────────────────────────────────

  double get averageScore {
    if (_trips.isEmpty) return 0;
    return _trips.map((t) => t.score.overall).reduce((a, b) => a + b) /
        _trips.length;
  }

  double get totalDistanceKm =>
      _trips.fold(0.0, (s, t) => s + t.distanceKm);

  int get totalEvents =>
      _trips.fold(0, (s, t) => s + t.events.length);

  double get bestScore =>
      _trips.isEmpty ? 0 : _trips.map((t) => t.score.overall).reduce((a, b) => a > b ? a : b);

  VehicleHealthModel get vehicleHealth =>
      VehicleHealthModel.fromTripHistory(_trips);

  /// Last 7 days of average scores, keyed by weekday abbreviation.
  List<Map<String, dynamic>> get weeklyScores {
    final now = DateTime.now();
    return List.generate(7, (i) {
      final day = now.subtract(Duration(days: 6 - i));
      final dayTrips = _trips.where((t) =>
          t.startTime.year == day.year &&
          t.startTime.month == day.month &&
          t.startTime.day == day.day);
      final score = dayTrips.isEmpty
          ? 0.0
          : dayTrips.map((t) => t.score.overall).reduce((a, b) => a + b) /
              dayTrips.length;
      return {
        'day': _weekdayShort(day.weekday),
        'score': score,
        'hasData': dayTrips.isNotEmpty,
      };
    });
  }

  static String _weekdayShort(int wd) =>
      ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'][wd - 1];

  // ─────────────────────────────────────────────────────────────────────────
  // Mock seed data
  // ─────────────────────────────────────────────────────────────────────────

  static List<TripModel> _mockTrips() {
    final now = DateTime.now();
    return [
      TripModel(
        id: 'trip_mock_001',
        startTime: now.subtract(const Duration(hours: 2)),
        endTime: now.subtract(const Duration(hours: 1, minutes: 10)),
        distanceKm: 18.4,
        maxSpeedKmh: 92.0,
        avgSpeedKmh: 44.5,
        score: DriverScoreModel(
          overall: 84.0, braking: 80.0, cornering: 90.0,
          speeding: 78.0, smoothness: 88.0,
          grade: DriverScoreModel.gradeFromScore(84.0),
        ),
        events: [
          TripEvent(
            type: TripEventType.harshBraking,
            timestamp: now.subtract(const Duration(hours: 1, minutes: 45)),
            value: 0.82,
            latitude: 31.5204, longitude: 74.3587,
            sourceClass: BehaviourClass.suddenBrake, confidence: 0.91,
          ),
          TripEvent(
            type: TripEventType.sharpTurn,
            timestamp: now.subtract(const Duration(hours: 1, minutes: 30)),
            value: 0.61,
            latitude: 31.5210, longitude: 74.3600,
            sourceClass: BehaviourClass.rightTurn, confidence: 0.78,
          ),
        ],
        route: _mockRoute(31.5204, 74.3587, 8),
        classCounts: {
          BehaviourClass.normal: 82,
          BehaviourClass.idle: 10,
          BehaviourClass.suddenBrake: 1,
          BehaviourClass.rightTurn: 1,
        },
      ),
      TripModel(
        id: 'trip_mock_002',
        startTime: now.subtract(const Duration(days: 1, hours: 3)),
        endTime: now.subtract(const Duration(days: 1, hours: 2, minutes: 5)),
        distanceKm: 8.1,
        maxSpeedKmh: 67.0,
        avgSpeedKmh: 31.0,
        score: DriverScoreModel(
          overall: 91.0, braking: 95.0, cornering: 88.0,
          speeding: 92.0, smoothness: 89.0,
          grade: DriverScoreModel.gradeFromScore(91.0),
        ),
        events: [],
        route: _mockRoute(31.5210, 74.3590, 6),
        classCounts: {
          BehaviourClass.normal: 78, BehaviourClass.idle: 12,
        },
      ),
      TripModel(
        id: 'trip_mock_003',
        startTime: now.subtract(const Duration(days: 2, hours: 7)),
        endTime: now.subtract(const Duration(days: 2, hours: 5, minutes: 40)),
        distanceKm: 42.7,
        maxSpeedKmh: 118.0,
        avgSpeedKmh: 68.0,
        score: DriverScoreModel(
          overall: 62.0, braking: 55.0, cornering: 60.0,
          speeding: 50.0, smoothness: 78.0,
          grade: DriverScoreModel.gradeFromScore(62.0),
        ),
        events: [
          TripEvent(type: TripEventType.speeding,
            timestamp: now.subtract(const Duration(days: 2, hours: 6)),
            value: 118.0, latitude: 31.5250, longitude: 74.3650,
            sourceClass: BehaviourClass.normal, confidence: 0.70),
          TripEvent(type: TripEventType.harshBraking,
            timestamp: now.subtract(const Duration(days: 2, hours: 5, minutes: 50)),
            value: 0.91, latitude: 31.5260, longitude: 74.3660,
            sourceClass: BehaviourClass.suddenBrake, confidence: 0.94),
          TripEvent(type: TripEventType.sharpTurn,
            timestamp: now.subtract(const Duration(days: 2, hours: 5, minutes: 45)),
            value: 0.74, latitude: 31.5265, longitude: 74.3670,
            sourceClass: BehaviourClass.leftTurn, confidence: 0.82),
        ],
        route: _mockRoute(31.5220, 74.3600, 12),
        classCounts: {
          BehaviourClass.normal: 60, BehaviourClass.idle: 8,
          BehaviourClass.suddenBrake: 3, BehaviourClass.leftTurn: 2,
          BehaviourClass.rightTurn: 1,
        },
      ),
    ];
  }

  static List<LatLngPoint> _mockRoute(double lat, double lng, int points) =>
      List.generate(points, (i) => LatLngPoint(
            latitude: lat + i * 0.0015,
            longitude: lng + i * 0.0010,
            speedKmh: 40 + i * 2.0,
          ));
}

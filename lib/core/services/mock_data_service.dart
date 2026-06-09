import '../../models/models.dart';

/// Provides mock data for UI development before backend is ready.
class MockDataService {
  MockDataService._();

  static UserModel get currentUser => UserModel(
        id: 'usr_001',
        fullName: 'Someone',
        email: 'someone@gmail.com',
        createdAt: DateTime(2024, 9, 1),
      );

  static VehicleHealthModel get vehicleHealth => VehicleHealthModel(
        overall: 73.0,
        engineHealth: 88.0,
        brakeWear: 61.0,
        suspensionStress: 70.0,
        tyrePressureScore: 82.0,
        lastUpdated: DateTime.now().subtract(const Duration(hours: 2)),
        insights: [
          const HealthInsight(
            title: 'Brake Wear Detected',
            description:
                'Frequent harsh braking over the last 7 trips has accelerated brake pad wear. Consider inspection within 2,000 km.',
            severity: 'warning',
          ),
          const HealthInsight(
            title: 'Suspension Under Stress',
            description:
                'Multiple sharp turn events detected. High lateral G-forces may stress suspension components.',
            severity: 'info',
          ),
          const HealthInsight(
            title: 'Engine Health Good',
            description: 'No anomalies detected in engine-related metrics.',
            severity: 'info',
          ),
        ],
      );

  static List<TripModel> get trips => [
        TripModel(
          id: 'trip_001',
          startTime: DateTime.now().subtract(const Duration(hours: 2)),
          endTime: DateTime.now().subtract(const Duration(hours: 1, minutes: 10)),
          distanceKm: 18.4,
          maxSpeedKmh: 92.0,
          avgSpeedKmh: 44.5,
          score: DriverScoreModel(
            overall: 84.0,
            braking: 80.0,
            cornering: 90.0,
            acceleration: 78.0,
            smoothness: 88.0,
            grade: DriverScoreModel.gradeFromScore(84.0),
          ),
          events: [
            TripEvent(
              id: 'evt_001_1',
              type: TripEventType.harshBraking,
              timestamp:
                  DateTime.now().subtract(const Duration(hours: 1, minutes: 45)),
              confidence: 0.82,
              latitude: 31.5204,
              longitude: 74.3587,
            ),
            TripEvent(
              id: 'evt_001_2',
              type: TripEventType.leftTurn,
              timestamp:
                  DateTime.now().subtract(const Duration(hours: 1, minutes: 30)),
              confidence: 0.61,
              latitude: 31.5210,
              longitude: 74.3600,
            ),
          ],
          route: _sampleRoute(),
        ),
        TripModel(
          id: 'trip_002',
          startTime: DateTime.now().subtract(const Duration(days: 1, hours: 3)),
          endTime:
              DateTime.now().subtract(const Duration(days: 1, hours: 2, minutes: 5)),
          distanceKm: 8.1,
          maxSpeedKmh: 67.0,
          avgSpeedKmh: 31.0,
          score: DriverScoreModel(
            overall: 91.0,
            braking: 95.0,
            cornering: 88.0,
            acceleration: 92.0,
            smoothness: 89.0,
            grade: DriverScoreModel.gradeFromScore(91.0),
          ),
          events: [],
          route: _sampleRoute(),
        ),
        TripModel(
          id: 'trip_003',
          startTime: DateTime.now().subtract(const Duration(days: 2, hours: 7)),
          endTime:
              DateTime.now().subtract(const Duration(days: 2, hours: 5, minutes: 40)),
          distanceKm: 42.7,
          maxSpeedKmh: 118.0,
          avgSpeedKmh: 68.0,
          score: DriverScoreModel(
            overall: 62.0,
            braking: 55.0,
            cornering: 60.0,
            acceleration: 50.0,
            smoothness: 78.0,
            grade: DriverScoreModel.gradeFromScore(62.0),
          ),
          events: [
            TripEvent(
              id: 'evt_003_1',
              type: TripEventType.hardAccel,
              timestamp:
                  DateTime.now().subtract(const Duration(days: 2, hours: 6)),
              confidence: 0.88,
              latitude: 31.5250,
              longitude: 74.3650,
            ),
            TripEvent(
              id: 'evt_003_2',
              type: TripEventType.harshBraking,
              timestamp: DateTime.now()
                  .subtract(const Duration(days: 2, hours: 5, minutes: 50)),
              confidence: 0.91,
              latitude: 31.5260,
              longitude: 74.3660,
            ),
            TripEvent(
              id: 'evt_003_3',
              type: TripEventType.rightTurn,
              timestamp: DateTime.now()
                  .subtract(const Duration(days: 2, hours: 5, minutes: 45)),
              confidence: 0.74,
              latitude: 31.5265,
              longitude: 74.3670,
            ),
          ],
          route: _sampleRoute(),
        ),
        TripModel(
          id: 'trip_004',
          startTime: DateTime.now().subtract(const Duration(days: 3, hours: 8)),
          endTime:
              DateTime.now().subtract(const Duration(days: 3, hours: 7, minutes: 15)),
          distanceKm: 11.2,
          maxSpeedKmh: 75.0,
          avgSpeedKmh: 38.0,
          score: DriverScoreModel(
            overall: 88.0,
            braking: 90.0,
            cornering: 85.0,
            acceleration: 87.0,
            smoothness: 90.0,
            grade: DriverScoreModel.gradeFromScore(88.0),
          ),
          events: [
            TripEvent(
              id: 'evt_004_1',
              type: TripEventType.hardAccel,
              timestamp:
                  DateTime.now().subtract(const Duration(days: 3, hours: 7, minutes: 50)),
              confidence: 0.55,
              latitude: 31.5215,
              longitude: 74.3590,
            ),
          ],
          route: _sampleRoute(),
        ),
      ];

  // Weekly score data for chart
  static List<Map<String, dynamic>> get weeklyScores => [
        {'day': 'Mon', 'score': 88.0},
        {'day': 'Tue', 'score': 91.0},
        {'day': 'Wed', 'score': 62.0},
        {'day': 'Thu', 'score': 84.0},
        {'day': 'Fri', 'score': 76.0},
        {'day': 'Sat', 'score': 90.0},
        {'day': 'Sun', 'score': 84.0},
      ];

  static List<LatLngPoint> _sampleRoute() => [
        const LatLngPoint(latitude: 31.5204, longitude: 74.3587),
        const LatLngPoint(latitude: 31.5215, longitude: 74.3600),
        const LatLngPoint(latitude: 31.5230, longitude: 74.3620),
        const LatLngPoint(latitude: 31.5245, longitude: 74.3640),
        const LatLngPoint(latitude: 31.5260, longitude: 74.3660),
        const LatLngPoint(latitude: 31.5275, longitude: 74.3680),
      ];
}

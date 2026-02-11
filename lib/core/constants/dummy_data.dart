import 'package:flutter/material.dart';

class DummyData {
  /// DASHBOARD DATA (Overview stats)
  static Map<String, dynamic> dashboard = {
    "score": 82,
    "quality": "Moderate",
    "totalTrips": 24,
    "harshBraking": 5,
    "overspeed": 3,
    "rapidAcceleration": 4,
    "collisions": 0,
    "rashEvents": 12,
    "weekScore": 80,
    "trendData": [70, 75, 82, 80, 85, 82],
  };

  /// ALERTS DATA (For the new Alerts Screen)
  static List<Map<String, dynamic>> alerts = [
    {
      "id": 1,
      "type": "Critical",
      "title": "Potential Collision",
      "description":
          "Sudden deceleration detected at Sector 4. Check vehicle for damage.",
      "time": "10 mins ago",
      "icon": Icons.car_crash,
      "color": Colors.red,
    },
    {
      "id": 2,
      "type": "High Risk",
      "title": "Extreme Speeding",
      "description": "Speed reached 125 km/h in a 60 km/h urban zone.",
      "time": "1 hour ago",
      "icon": Icons.speed,
      "color": Colors.orange,
    },
    {
      "id": 3,
      "type": "Notification",
      "title": "Harsh Acceleration",
      "description": "Repeated rapid starts detected during your last trip.",
      "time": "Yesterday",
      "icon": Icons.trending_up,
      "color": Colors.amber,
    },
  ];

  /// TRIPS LIST (5 Polished Entries)
  static List<Map<String, dynamic>> trips = [
    {
      "id": 1,
      "date": "Apr 12, 2026",
      "duration": "45 mins",
      "score": 88,
      "events": 3,
      "distance": "12.4 km",
      "harshBrakes": 1,
      "overspeed": 2,
      "acceleration": 0,
      "collisions": 0,
      "recommendations": [
        "Maintain safer speed in urban zones",
        "Smooth braking improves fuel efficiency",
      ],
    },
    {
      "id": 2,
      "date": "Apr 11, 2026",
      "duration": "30 mins",
      "score": 72,
      "events": 5,
      "distance": "7.8 km",
      "harshBrakes": 3,
      "overspeed": 2,
      "acceleration": 1,
      "collisions": 0,
      "recommendations": [
        "Avoid sudden braking",
        "Gradual acceleration reduces wear & tear",
      ],
    },
    {
      "id": 3,
      "date": "Apr 10, 2026",
      "duration": "1 hr 15 mins",
      "score": 95,
      "events": 1,
      "distance": "52.0 km",
      "harshBrakes": 0,
      "overspeed": 1,
      "acceleration": 0,
      "collisions": 0,
      "recommendations": [
        "Excellent highway lane discipline",
        "Consistency in speed noted",
      ],
    },
    {
      "id": 4,
      "date": "Apr 09, 2026",
      "duration": "20 mins",
      "score": 45,
      "events": 12,
      "distance": "4.2 km",
      "harshBrakes": 6,
      "overspeed": 4,
      "acceleration": 2,
      "collisions": 0,
      "recommendations": [
        "High frequency of harsh braking detected",
        "Keep a safe following distance from vehicles",
      ],
    },
    {
      "id": 5,
      "date": "Apr 08, 2026",
      "duration": "55 mins",
      "score": 81,
      "events": 4,
      "distance": "18.5 km",
      "harshBrakes": 2,
      "overspeed": 0,
      "acceleration": 2,
      "collisions": 0,
      "recommendations": [
        "Good speed management",
        "Focus on smoother standing starts",
      ],
    },
  ];
}

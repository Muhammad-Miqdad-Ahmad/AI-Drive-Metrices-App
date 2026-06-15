import 'package:supabase_flutter/supabase_flutter.dart';
import '../../models/models.dart';

/// Single source of truth for all Supabase queries.
/// All queries are filtered by [deviceToken] (loaded from local storage).
class SupabaseService {
  SupabaseService({required this.deviceToken});

  final String deviceToken;
  final _client = Supabase.instance.client;

  // ─── Trips ────────────────────────────────────────────────────────────────

  /// Fetch recent trips with their driver_scores joined.
  /// Returns newest-first.
  Future<List<TripModel>> getRecentTrips({int limit = 20}) async {
    final data = await _client
        .from('trips')
        .select('*, driver_scores(*)')
        .eq('device_token', deviceToken)
        .order('start_time', ascending: false)
        .limit(limit);

    return (data as List)
        .map((row) => TripModel.fromSupabase(row as Map<String, dynamic>))
        .toList();
  }

  /// Fetch a single trip by its Supabase UUID, with score + events + route.
  Future<TripModel?> getTripDetail(String tripId) async {
    final tripData = await _client
        .from('trips')
        .select('*, driver_scores(*)')
        .eq('id', tripId)
        .eq('device_token', deviceToken)
        .maybeSingle();

    if (tripData == null) return null;

    final eventsData = await _client
        .from('trip_events')
        .select()
        .eq('trip_id', tripId)
        .order('recorded_at');

    final routeData = await _client
        .from('route_points')
        .select()
        .eq('trip_id', tripId)
        .order('recorded_at');

    return TripModel.fromSupabase(
      tripData,
      events: (eventsData as List)
          .map((e) => TripEvent.fromSupabase(e as Map<String, dynamic>))
          .toList(),
      route: (routeData as List)
          .map((p) => LatLngPoint.fromSupabase(p as Map<String, dynamic>))
          .toList(),
    );
  }

  // ─── Dashboard stats ──────────────────────────────────────────────────────

  /// Aggregate stats across all trips for this device.
  Future<DashboardStats> getDashboardStats() async {
    final data = await _client
        .from('trips')
        .select('distance_km, driver_scores(overall, harsh_event_count)')
        .eq('device_token', deviceToken);

    final rows = data as List;
    if (rows.isEmpty) {
      return DashboardStats.empty();
    }

    double totalKm = 0;
    int totalEvents = 0;
    double scoreSum = 0;
    double bestScore = 0;

    for (final row in rows) {
      totalKm += (row['distance_km'] as num?)?.toDouble() ?? 0;
      final score = row['driver_scores'];
      if (score != null) {
        final s = (score['overall'] as num?)?.toDouble() ?? 0;
        scoreSum += s;
        if (s > bestScore) bestScore = s;
        totalEvents += (score['harsh_event_count'] as int?) ?? 0;
      }
    }

    return DashboardStats(
      totalTrips: rows.length,
      totalKm: totalKm,
      totalHarshEvents: totalEvents,
      avgScore: rows.isEmpty ? 0 : scoreSum / rows.length,
      bestScore: bestScore,
    );
  }

  // ─── ThingSpeak-sourced readings ──────────────────────────────────────────

  /// Latest sensor reading synced from ThingSpeak (Prediction, Confidence,
  /// Speed, Lat/Lng, worst G of the window).
  Future<DeviceReading?> getLatestReading() async {
    final data = await _client
        .from('device_readings')
        .select()
        .eq('device_token', deviceToken)
        .order('recorded_at', ascending: false)
        .limit(1)
        .maybeSingle();

    if (data == null) return null;
    return DeviceReading.fromSupabase(data);
  }

  /// Recent readings synced from ThingSpeak, newest first.
  Future<List<DeviceReading>> getRecentReadings({int limit = 50}) async {
    final data = await _client
        .from('device_readings')
        .select()
        .eq('device_token', deviceToken)
        .order('recorded_at', ascending: false)
        .limit(limit);

    return (data as List)
        .map((row) => DeviceReading.fromSupabase(row as Map<String, dynamic>))
        .toList();
  }

  /// Last 7 days of scores for the weekly chart (one per trip, ordered by day).
  Future<List<Map<String, dynamic>>> getWeeklyScores() async {
    final since = DateTime.now().subtract(const Duration(days: 7));
    final data = await _client
        .from('trips')
        .select('start_time, driver_scores(overall)')
        .eq('device_token', deviceToken)
        .gte('start_time', since.toIso8601String())
        .order('start_time');

    // Group by weekday label, average if multiple trips same day
    final Map<String, List<double>> grouped = {};
    const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

    for (final row in (data as List)) {
      final dt = DateTime.parse(row['start_time'] as String).toLocal();
      final label = days[dt.weekday - 1]; // weekday: 1=Mon
      final score =
          (row['driver_scores']?['overall'] as num?)?.toDouble() ?? 0;
      grouped.putIfAbsent(label, () => []).add(score);
    }

    // Build chart-ready list ordered Mon→Sun, filling blanks with 0
    return days.map((day) {
      final scores = grouped[day] ?? [];
      final avg = scores.isEmpty
          ? 0.0
          : scores.reduce((a, b) => a + b) / scores.length;
      return {'day': day, 'score': avg};
    }).toList();
  }
}

// ─── Dashboard stats model ─────────────────────────────────────────────────

class DashboardStats {
  final int totalTrips;
  final double totalKm;
  final int totalHarshEvents;
  final double avgScore;
  final double bestScore;

  const DashboardStats({
    required this.totalTrips,
    required this.totalKm,
    required this.totalHarshEvents,
    required this.avgScore,
    required this.bestScore,
  });

  factory DashboardStats.empty() => const DashboardStats(
        totalTrips: 0,
        totalKm: 0,
        totalHarshEvents: 0,
        avgScore: 0,
        bestScore: 0,
      );
}
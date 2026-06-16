import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../models/models.dart';

/// Single source of truth for all Supabase queries.
/// All queries are filtered by [deviceToken] (loaded from local storage).
class SupabaseService {
  SupabaseService({required this.deviceToken}) {
    assert(deviceToken.isNotEmpty, 'SupabaseService: deviceToken must not be empty');
    debugPrint('🔑 SupabaseService created with token: "$deviceToken"');
  }

  final String deviceToken;
  final _client = Supabase.instance.client;

  // ─── Trips ────────────────────────────────────────────────────────────────

  /// Fetch recent trips with their driver_scores joined.
  /// Returns newest-first. Filters out trips with bad timestamps (pre-2020).
  Future<List<TripModel>> getRecentTrips({int limit = 20}) async {
    debugPrint('📡 getRecentTrips: querying for device_token="$deviceToken"');

    final data = await _client
        .from('trips')
        .select('*, driver_scores(*)')
        .eq('device_token', deviceToken)
  
        .order('start_time', ascending: false)
        .limit(limit);

    final rows = data as List;
    debugPrint('📦 getRecentTrips: got ${rows.length} rows');

    final trips = <TripModel>[];
    for (final row in rows) {
      try {
        trips.add(TripModel.fromSupabase(row as Map<String, dynamic>));
      } catch (e) {
        debugPrint('⚠️ getRecentTrips: failed to parse row ${row['id']}: $e');
      }
    }
    return trips;
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
        .eq('device_token', deviceToken)
        .gte('start_time', '2020-01-01T00:00:00Z'); // guard against epoch rows

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

  /// Latest sensor reading synced from ThingSpeak.
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

    final Map<String, List<double>> grouped = {};
    const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

    for (final row in (data as List)) {
      final dt = DateTime.parse(row['start_time'] as String).toLocal();
      final label = days[dt.weekday - 1];
      final score =
          (row['driver_scores']?['overall'] as num?)?.toDouble() ?? 0;
      grouped.putIfAbsent(label, () => []).add(score);
    }

    return days.map((day) {
      final scores = grouped[day] ?? [];
      final avg = scores.isEmpty
          ? 0.0
          : scores.reduce((a, b) => a + b) / scores.length;
      return {'day': day, 'score': avg};
    }).toList();
  }

  // ─── Debug helper ─────────────────────────────────────────────────────────

  /// Prints a diagnostic dump to the debug console.
  /// Call this from the Trips screen if no trips appear.
  Future<void> debugDump() async {
    debugPrint('─── SupabaseService.debugDump ───');
    debugPrint('  deviceToken = "$deviceToken"');

    try {
      final readings = await _client
          .from('device_readings')
          .select('id, device_token, recorded_at')
          .eq('device_token', deviceToken)
          .order('recorded_at', ascending: false)
          .limit(3);
      debugPrint('  device_readings (latest 3): $readings');
    } catch (e) {
      debugPrint('  device_readings error: $e');
    }

    try {
      final allTrips = await _client
          .from('trips')
          .select('id, device_token, local_trip_id, start_time')
          .order('start_time', ascending: false)
          .limit(5);
      debugPrint('  trips (all, latest 5, no filter): $allTrips');
    } catch (e) {
      debugPrint('  trips error: $e');
    }

    try {
      final myTrips = await _client
          .from('trips')
          .select('id, device_token, start_time')
          .eq('device_token', deviceToken)
          .limit(5);
      debugPrint('  trips (filtered by token): $myTrips');
    } catch (e) {
      debugPrint('  trips filtered error: $e');
    }
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

// ─── Trip-flush helpers (pair with Supabase trigger) ──────────────────────

extension TripFlushExtension on SupabaseService {
  /// Manually trigger a flush of all current device_readings → one trip.
  /// Under normal operation this is NOT needed — the DB trigger fires
  /// automatically on each INSERT.  Call this only from a "End Trip" button
  /// or an Edge Function if you want an explicit manual flush.
  Future<void> manualFlushToTrip() async {
    await _client.rpc('flush_readings_to_trip', params: {
      'p_device_token': deviceToken,
    });
    debugPrint('✅ manualFlushToTrip: flush complete for $deviceToken');
  }

  /// Returns a real-time [Stream] that emits the latest reading count in
  /// device_readings for this device.  When the count drops to 0 after being
  /// >0, a new trip was just committed — refresh your trips list.
  Stream<int> watchPendingReadingCount() {
    return _client
        .from('device_readings')
        .stream(primaryKey: ['id'])
        .eq('device_token', deviceToken)
        .map((rows) => rows.length);
  }

  /// Sends the end-of-trip sentinel row so the DB trigger flushes immediately.
  /// Use this from your Flutter app's "Stop Trip" button instead of waiting
  /// for ThingSpeak to post '-1'.
  Future<void> sendTripEndSignal() async {
    await _client.from('device_readings').insert({
      'device_token': deviceToken,
      'prediction': '-1',
      'confidence': 0,
      'speed_kmh': 0,
      'latitude': 0,
      'longitude': 0,
      'g_worst': 0,
      'recorded_at': DateTime.now().toUtc().toIso8601String(),
    });
    debugPrint('🏁 sendTripEndSignal: sentinel posted for $deviceToken');
  }
}
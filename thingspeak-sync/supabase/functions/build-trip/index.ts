// supabase/functions/build-trip/index.ts
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';

const supabase = createClient(
  Deno.env.get('SUPABASE_URL')!,
  Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!,
);

Deno.serve(async (_req) => {
  try {
    // 1. Fetch all unprocessed readings, ordered by time
    const { data: readings, error: readErr } = await supabase
      .from('device_readings')
      .select('*')
      .eq('processed', false)
      .order('recorded_at', { ascending: true });

    if (readErr) throw readErr;
    if (!readings || readings.length === 0) {
      return jsonResponse({ message: 'No unprocessed readings' });
    }

    // Group by device_token (in case multiple devices feed this table)
    const byDevice = new Map<string, typeof readings>();
    for (const r of readings) {
      const arr = byDevice.get(r.device_token) ?? [];
      arr.push(r);
      byDevice.set(r.device_token, arr);
    }

    const results = [];

    for (const [deviceToken, rows] of byDevice) {
      const startTime = rows[0].recorded_at;
      const endTime = rows[rows.length - 1].recorded_at;

      const speeds = rows
        .map((r) => r.speed_kmh)
        .filter((s) => s != null) as number[];
      const maxSpeed = speeds.length ? Math.max(...speeds) : null;
      const avgSpeed = speeds.length
        ? speeds.reduce((a, b) => a + b, 0) / speeds.length
        : null;

      const distanceKm = computeDistanceKm(rows);

      // 2. Insert trip
      const { data: trip, error: tripErr } = await supabase
        .from('trips')
        .insert({
          device_token: deviceToken,
          local_trip_id: `trip-${Date.now()}`,
          start_time: startTime,
          end_time: endTime,
          distance_km: distanceKm,
          max_speed_kmh: maxSpeed,
          avg_speed_kmh: avgSpeed,
        })
        .select()
        .single();

      if (tripErr) throw tripErr;

      // 3. Insert route points
      const routePoints = rows
        .filter((r) => r.latitude != null && r.longitude != null)
        .map((r) => ({
          trip_id: trip.id,
          latitude: r.latitude,
          longitude: r.longitude,
          speed_kmh: r.speed_kmh,
          recorded_at: r.recorded_at,
        }));

      if (routePoints.length > 0) {
        const { error: rpErr } = await supabase
          .from('route_points')
          .insert(routePoints);
        if (rpErr) throw rpErr;
      }

      // 4. Insert trip events (harsh events, where prediction != "0"/normal)
      const events = rows
        .filter((r) => r.prediction && r.prediction !== '0')
        .map((r) => ({
          trip_id: trip.id,
          event_label: parseInt(r.prediction!, 10) || 0,
          event_name: r.prediction,
          confidence: r.confidence,
          latitude: r.latitude,
          longitude: r.longitude,
          speed_kmh: r.speed_kmh,
          recorded_at: r.recorded_at,
        }));

      if (events.length > 0) {
        const { error: evErr } = await supabase
          .from('trip_events')
          .insert(events);
        if (evErr) throw evErr;
      }

      // 5. Compute and insert driver score
      const harshCount = events.length;
      const overall = computeOverallScore(rows, harshCount);

      const { error: scoreErr } = await supabase.from('driver_scores').insert({
        trip_id: trip.id,
        overall,
        braking: null,
        cornering: null,
        acceleration: null,
        smoothness: null,
        grade: gradeFromScore(overall),
        harsh_event_count: harshCount,
      });
      if (scoreErr) throw scoreErr;

      // 6. Mark readings as processed
      const ids = rows.map((r) => r.id);
      const { error: updateErr } = await supabase
        .from('device_readings')
        .update({ processed: true })
        .in('id', ids);
      if (updateErr) throw updateErr;

      results.push({
        deviceToken,
        tripId: trip.id,
        points: routePoints.length,
        events: events.length,
      });
    }

    return jsonResponse({ message: 'Trips built', results });
  } catch (err) {
    console.error(err);
    return jsonResponse({ error: serializeError(err) }, 500);
  }
});

// ── Helpers ──────────────────────────────────────────────────────────────────

function computeDistanceKm(
  rows: { latitude: number | null; longitude: number | null }[],
): number {
  let total = 0;
  for (let i = 1; i < rows.length; i++) {
    const a = rows[i - 1];
    const b = rows[i];
    if (
      a.latitude == null ||
      a.longitude == null ||
      b.latitude == null ||
      b.longitude == null
    )
      continue;
    total += haversineKm(a.latitude, a.longitude, b.latitude, b.longitude);
  }
  return Math.round(total * 1000) / 1000;
}

function haversineKm(
  lat1: number,
  lon1: number,
  lat2: number,
  lon2: number,
): number {
  const R = 6371;
  const dLat = ((lat2 - lat1) * Math.PI) / 180;
  const dLon = ((lon2 - lon1) * Math.PI) / 180;
  const a =
    Math.sin(dLat / 2) ** 2 +
    Math.cos((lat1 * Math.PI) / 180) *
      Math.cos((lat2 * Math.PI) / 180) *
      Math.sin(dLon / 2) ** 2;
  return R * 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
}

function computeOverallScore(
  rows: { g_worst: number | null }[],
  harshCount: number,
): number {
  // Simple placeholder scoring: start at 100, deduct per harsh event
  const score = 100 - harshCount * 5;
  return Math.max(0, Math.min(100, score));
}

function gradeFromScore(score: number): string {
  if (score >= 90) return 'A';
  if (score >= 75) return 'B';
  if (score >= 60) return 'C';
  return 'D';
}

function serializeError(err: unknown): unknown {
  if (err instanceof Error)
    return { name: err.name, message: err.message, stack: err.stack };
  if (err && typeof err === 'object') {
    const { message, details, hint, code } = err as Record<string, unknown>;
    return { message, details, hint, code };
  }
  return { value: String(err) };
}

function jsonResponse(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { 'Content-Type': 'application/json' },
  });
}

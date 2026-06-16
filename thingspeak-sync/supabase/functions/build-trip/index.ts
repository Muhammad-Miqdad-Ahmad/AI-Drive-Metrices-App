// supabase/functions/build-trip/index.ts
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';

const supabase = createClient(
  Deno.env.get('SUPABASE_URL')!,
  Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!,
);

Deno.serve(async (_req) => {
  try {
    // 1. Fetch all unprocessed readings, ordered by ThingSpeak server time.
    //    `recorded_at` is now ThingSpeak's created_at — always a real UTC date.
    const { data: readings, error: readErr } = await supabase
      .from('device_readings')
      .select('*')
      .eq('processed', false)
      .order('recorded_at', { ascending: true });

    if (readErr) throw readErr;
    if (!readings || readings.length === 0) {
      return jsonResponse({ message: 'No unprocessed readings' });
    }

    // ✅ Filter out any rows still carrying epoch/bad timestamps (pre-2020).
    // These are legacy rows from before the sync fix; ignore them so they
    // don't corrupt trip times.
    const EPOCH_CUTOFF = new Date('2020-01-01T00:00:00Z').getTime();
    const validReadings = readings.filter(
      (r) => new Date(r.recorded_at).getTime() >= EPOCH_CUTOFF,
    );

    if (validReadings.length === 0) {
      // Mark the bad rows processed so they're never retried
      const ids = readings.map((r) => r.id);
      await supabase
        .from('device_readings')
        .update({ processed: true })
        .in('id', ids);
      return jsonResponse({
        message: 'Only epoch rows found — marked processed, no trip built',
      });
    }

    // Group by device_token
    const byDevice = new Map<string, typeof validReadings>();
    for (const r of validReadings) {
      const arr = byDevice.get(r.device_token) ?? [];
      arr.push(r);
      byDevice.set(r.device_token, arr);
    }

    const results = [];

    for (const [deviceToken, rows] of byDevice) {
      // ✅ start_time / end_time now come from recorded_at which is
      //    ThingSpeak's server timestamp — always a real UTC datetime.
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

      // 4. Insert trip events
      // prediction values: "0" or "1" = normal/idle, "2"+ = harsh events
      // We store ALL non-null predictions as events (the app filters by type).
      const events = rows
        .filter((r) => r.prediction != null && r.prediction !== '-1')
        .map((r) => ({
          trip_id: trip.id,
          event_label: parseInt(r.prediction!, 10) || 0,
          event_name: r.prediction,
          confidence: r.confidence,
          latitude: r.latitude,
          longitude: r.longitude,
          speed_kmh: r.speed_kmh,
          recorded_at: r.recorded_at,
          // ✅ carry g_worst through to trip_events so the app can display it
          // (requires a g_worst column on trip_events — see migration note below)
          // g_worst: r.g_worst,
        }));

      if (events.length > 0) {
        const { error: evErr } = await supabase
          .from('trip_events')
          .insert(events);
        if (evErr) throw evErr;
      }

      // 5. Compute and insert driver score
      // Harsh events = prediction labels 2, 3, 4, 5 (hardAccel, rightTurn,
      // leftTurn, harshBraking). Labels 0 and 1 are idle / normal driving.
      const harshCount = rows.filter((r) => {
        const label = parseInt(r.prediction ?? '0', 10);
        return label >= 2;
      }).length;

      const gValues = rows
        .map((r) => r.g_worst)
        .filter((g): g is number => g != null && g > 0);
      const avgG = gValues.length
        ? gValues.reduce((a, b) => a + b, 0) / gValues.length
        : 0;

      const overall = computeOverallScore(harshCount, avgG, rows.length);

      const { error: scoreErr } = await supabase.from('driver_scores').insert({
        trip_id: trip.id,
        overall,
        braking: computeCategoryScore(rows, [5]), // harshBraking
        cornering: computeCategoryScore(rows, [3, 4]), // turns
        acceleration: computeCategoryScore(rows, [2]), // hardAccel
        smoothness: computeSmoothnessScore(gValues),
        grade: gradeFromScore(overall),
        harsh_event_count: harshCount,
      });
      if (scoreErr) throw scoreErr;

      // 6. Mark ALL fetched readings as processed (including any epoch ones
      //    that were excluded from this trip)
      const ids = rows.map((r) => r.id);
      const { error: updateErr } = await supabase
        .from('device_readings')
        .update({ processed: true })
        .in('id', ids);
      if (updateErr) throw updateErr;

      results.push({
        deviceToken,
        tripId: trip.id,
        startTime,
        endTime,
        points: routePoints.length,
        events: events.length,
        harshCount,
      });
    }

    return jsonResponse({ message: 'Trips built', results });
  } catch (err) {
    console.error(err);
    return jsonResponse({ error: serializeError(err) }, 500);
  }
});

// ── Score helpers ─────────────────────────────────────────────────────────────

/**
 * Overall score: start at 100, penalise harsh events and high average g-force.
 */
function computeOverallScore(
  harshCount: number,
  avgG: number,
  totalRows: number,
): number {
  // -5 per harsh event, -10 per 0.1g above 0.2g average
  const harshPenalty = harshCount * 5;
  const gPenalty = Math.max(0, (avgG - 0.2) / 0.1) * 10;
  return Math.round(Math.max(0, Math.min(100, 100 - harshPenalty - gPenalty)));
}

/**
 * Category score: percentage of readings NOT in given harsh labels, scaled 0–100.
 */
function computeCategoryScore(
  rows: { prediction: string | null }[],
  harshLabels: number[],
): number {
  const harshInCategory = rows.filter((r) =>
    harshLabels.includes(parseInt(r.prediction ?? '0', 10)),
  ).length;
  return Math.round(
    Math.max(0, 100 - (harshInCategory / rows.length) * 100 * 5),
  );
}

/**
 * Smoothness score based on average g_worst: lower g = smoother.
 */
function computeSmoothnessScore(gValues: number[]): number {
  if (gValues.length === 0) return 100;
  const avg = gValues.reduce((a, b) => a + b, 0) / gValues.length;
  // 0g → 100, 1g → 0 (linear clamp)
  return Math.round(Math.max(0, Math.min(100, 100 - avg * 100)));
}

// ── Distance helper ───────────────────────────────────────────────────────────

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

// ── Misc helpers ──────────────────────────────────────────────────────────────

function gradeFromScore(score: number): string {
  if (score >= 90) return 'A+';
  if (score >= 80) return 'A';
  if (score >= 70) return 'B';
  if (score >= 60) return 'C';
  if (score >= 50) return 'D';
  return 'F';
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

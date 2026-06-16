// supabase/functions/build-trip/index.ts
//
// Reads unprocessed device_readings, segments them into trips using a
// 30-minute idle gap, computes driver scores, and marks rows processed.
//
// Trip boundary rule:
//   If the gap between two consecutive readings exceeds TRIP_GAP_MS (30 min),
//   the current trip is closed and a new one starts.

import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';

const supabase = createClient(
  Deno.env.get('SUPABASE_URL')!,
  Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!,
);

// ── Config ────────────────────────────────────────────────────────────────────
/** Readings more than this far apart in time start a new trip (30 minutes). */
const TRIP_GAP_MS = 30 * 60 * 1000;

/** Ignore rows with timestamps before 2020 (epoch/corrupt data). */
const EPOCH_CUTOFF = new Date('2020-01-01T00:00:00Z').getTime();

// ── Entry point ───────────────────────────────────────────────────────────────
Deno.serve(async (_req) => {
  try {
    // 1. Fetch all unprocessed readings, oldest-first.
    const { data: readings, error: readErr } = await supabase
      .from('device_readings')
      .select('*')
      .eq('processed', false)
      .order('recorded_at', { ascending: true });

    if (readErr) throw readErr;
    if (!readings || readings.length === 0) {
      return jsonResponse({ message: 'No unprocessed readings' });
    }

    // 2. Separate valid rows from legacy epoch rows.
    const validReadings = readings.filter(
      (r) => new Date(r.recorded_at).getTime() >= EPOCH_CUTOFF,
    );
    const badIds = readings
      .filter((r) => new Date(r.recorded_at).getTime() < EPOCH_CUTOFF)
      .map((r) => r.id);

    if (badIds.length > 0) {
      await supabase
        .from('device_readings')
        .update({ processed: true })
        .in('id', badIds);
    }

    if (validReadings.length === 0) {
      return jsonResponse({
        message: 'Only epoch rows found — marked processed, no trip built',
        markedProcessed: badIds.length,
      });
    }

    // 3. Group by device_token.
    const byDevice = new Map<string, typeof validReadings>();
    for (const r of validReadings) {
      const arr = byDevice.get(r.device_token) ?? [];
      arr.push(r);
      byDevice.set(r.device_token, arr);
    }

    const results = [];

    for (const [deviceToken, rows] of byDevice) {
      // 4. Segment into time-windowed trips (gap > 30 min → new trip).
      const segments = segmentByGap(rows, TRIP_GAP_MS);

      for (const segment of segments) {
        // Skip segments that are too short to be meaningful (< 2 points).
        if (segment.length < 2) {
          // Still mark as processed so they don't pile up.
          const ids = segment.map((r) => r.id);
          await supabase
            .from('device_readings')
            .update({ processed: true })
            .in('id', ids);
          continue;
        }

        const result = await buildTripFromSegment(deviceToken, segment);
        results.push(result);
      }
    }

    return jsonResponse({ message: 'Trips built', results });
  } catch (err) {
    console.error(err);
    return jsonResponse({ error: serializeError(err) }, 500);
  }
});

// ── Core: build one trip from a segment of readings ───────────────────────────
async function buildTripFromSegment(
  deviceToken: string,
  rows: Record<string, unknown>[],
) {
  const startTime = rows[0].recorded_at as string;
  const endTime = rows[rows.length - 1].recorded_at as string;

  const speeds = rows
    .map((r) => r.speed_kmh as number | null)
    .filter((s): s is number => s != null);
  const maxSpeed = speeds.length ? Math.max(...speeds) : null;
  const avgSpeed = speeds.length
    ? speeds.reduce((a, b) => a + b, 0) / speeds.length
    : null;

  const distanceKm = computeDistanceKm(
    rows as { latitude: number | null; longitude: number | null }[],
  );

  // ── Insert trip ──────────────────────────────────────────────────────────
  const { data: trip, error: tripErr } = await supabase
    .from('trips')
    .insert({
      device_token: deviceToken,
      local_trip_id: `trip-${Date.now()}-${Math.random().toString(36).slice(2, 7)}`,
      start_time: startTime,
      end_time: endTime,
      distance_km: distanceKm,
      max_speed_kmh: maxSpeed,
      avg_speed_kmh: avgSpeed,
    })
    .select()
    .single();

  if (tripErr) throw tripErr;

  // ── Insert route points ──────────────────────────────────────────────────
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

  // ── Insert trip events ───────────────────────────────────────────────────
  // prediction labels: 0 = idle, 1 = normal, 2 = hardAccel,
  //                    3 = rightTurn, 4 = leftTurn, 5 = harshBraking
  const events = rows
    .filter(
      (r) =>
        r.prediction != null &&
        r.prediction !== '-1' &&
        r.prediction !== 'null',
    )
    .map((r) => ({
      trip_id: trip.id,
      event_label: parseInt(r.prediction as string, 10) || 0,
      event_name: labelToName(parseInt(r.prediction as string, 10) || 0),
      confidence: r.confidence,
      latitude: r.latitude,
      longitude: r.longitude,
      speed_kmh: r.speed_kmh,
      recorded_at: r.recorded_at,
      g_worst: r.g_worst,
    }));

  if (events.length > 0) {
    const { error: evErr } = await supabase.from('trip_events').insert(events);
    if (evErr) throw evErr;
  }

  // ── Compute driver score ─────────────────────────────────────────────────
  const harshRows = rows.filter((r) => {
    const label = parseInt((r.prediction as string) ?? '0', 10);
    return label >= 2;
  });
  const harshCount = harshRows.length;

  const gValues = rows
    .map((r) => r.g_worst as number | null)
    .filter((g): g is number => g != null && g > 0);
  const avgG = gValues.length
    ? gValues.reduce((a, b) => a + b, 0) / gValues.length
    : 0;

  const overallScore = computeOverallScore(harshCount, avgG, rows.length);
  const brakingScore = computeCategoryScore(rows, [5]);
  const accelScore = computeCategoryScore(rows, [2]);
  const corneringScore = computeCategoryScore(rows, [3, 4]);
  const smoothnessScore = computeSmoothnessScore(gValues);

  // Counts per category
  const harshBrakingCount = rows.filter(
    (r) => parseInt((r.prediction as string) ?? '0', 10) === 5,
  ).length;
  const harshAccelCount = rows.filter(
    (r) => parseInt((r.prediction as string) ?? '0', 10) === 2,
  ).length;
  const harshCorneringCount = rows.filter(
    (r) =>
      parseInt((r.prediction as string) ?? '0', 10) === 3 ||
      parseInt((r.prediction as string) ?? '0', 10) === 4,
  ).length;

  // ⚠️  Use the real column names from the schema (braking_score etc.),
  //     not the alias columns.
  const { error: scoreErr } = await supabase.from('driver_scores').insert({
    trip_id: trip.id,
    // Real score columns (0–100)
    overall_score: overallScore,
    braking_score: brakingScore,
    acceleration_score: accelScore,
    cornering_score: corneringScore,
    speeding_score: 100, // speeding detection not implemented yet
    // Count columns
    harsh_braking_count: harshBrakingCount,
    harsh_accel_count: harshAccelCount,
    harsh_cornering_count: harshCorneringCount,
    speeding_count: 0,
    harsh_event_count: harshCount,
    // Metadata
    grade: gradeFromScore(overallScore),
    distance_km: distanceKm,
    algorithm_version: 'v2-gap-segmented',
  });
  if (scoreErr) throw scoreErr;

  // ── Mark readings as processed ───────────────────────────────────────────
  const ids = rows.map((r) => r.id as string);
  const { error: updateErr } = await supabase
    .from('device_readings')
    .update({ processed: true })
    .in('id', ids);
  if (updateErr) throw updateErr;

  return {
    deviceToken,
    tripId: trip.id,
    startTime,
    endTime,
    durationMinutes: Math.round(
      (new Date(endTime).getTime() - new Date(startTime).getTime()) / 60000,
    ),
    points: routePoints.length,
    events: events.length,
    harshCount,
    overallScore,
    distanceKm,
  };
}

// ── Trip segmentation ─────────────────────────────────────────────────────────
/**
 * Split an ordered array of readings into sub-arrays where consecutive
 * readings are no more than `gapMs` milliseconds apart.
 */
function segmentByGap<T extends { recorded_at: string }>(
  rows: T[],
  gapMs: number,
): T[][] {
  if (rows.length === 0) return [];

  const segments: T[][] = [];
  let current: T[] = [rows[0]];

  for (let i = 1; i < rows.length; i++) {
    const prev = new Date(rows[i - 1].recorded_at).getTime();
    const curr = new Date(rows[i].recorded_at).getTime();
    if (curr - prev > gapMs) {
      // Gap exceeded — close current trip, start new one
      segments.push(current);
      current = [];
    }
    current.push(rows[i]);
  }
  if (current.length > 0) segments.push(current);

  return segments;
}

// ── Score helpers ─────────────────────────────────────────────────────────────
function computeOverallScore(
  harshCount: number,
  avgG: number,
  totalRows: number,
): number {
  const harshPenalty = harshCount * 5;
  const gPenalty = Math.max(0, (avgG - 0.2) / 0.1) * 10;
  return Math.round(Math.max(0, Math.min(100, 100 - harshPenalty - gPenalty)));
}

function computeCategoryScore(
  rows: { prediction: string | null | unknown }[],
  harshLabels: number[],
): number {
  const harshInCategory = rows.filter((r) =>
    harshLabels.includes(parseInt((r.prediction as string) ?? '0', 10)),
  ).length;
  return Math.round(
    Math.max(0, 100 - (harshInCategory / rows.length) * 100 * 5),
  );
}

function computeSmoothnessScore(gValues: number[]): number {
  if (gValues.length === 0) return 100;
  const avg = gValues.reduce((a, b) => a + b, 0) / gValues.length;
  return Math.round(Math.max(0, Math.min(100, 100 - avg * 100)));
}

function gradeFromScore(score: number): string {
  if (score >= 90) return 'A+';
  if (score >= 80) return 'A';
  if (score >= 70) return 'B';
  if (score >= 60) return 'C';
  if (score >= 50) return 'D';
  return 'F';
}

function labelToName(label: number): string {
  const names: Record<number, string> = {
    0: 'idle',
    1: 'normal',
    2: 'hardAccel',
    3: 'rightTurn',
    4: 'leftTurn',
    5: 'harshBraking',
  };
  return names[label] ?? `unknown_${label}`;
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

// ── Misc ──────────────────────────────────────────────────────────────────────
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

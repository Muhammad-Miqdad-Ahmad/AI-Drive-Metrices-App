// supabase/functions/thingspeak-sync/index.ts
//
// Pulls new entries from a ThingSpeak channel, stores them in
// `device_readings`, and clears the ThingSpeak feed once everything
// has been safely copied over.
//
// Required secrets (set via `supabase secrets set ...`):
//   THINGSPEAK_CHANNEL_ID
//   THINGSPEAK_READ_API_KEY
//   THINGSPEAK_WRITE_API_KEY
//   THINGSPEAK_DEVICE_TOKEN     -> device_token to attach to each row
//   SUPABASE_URL                (auto-provided)
//   SUPABASE_SERVICE_ROLE_KEY   (auto-provided)

import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';

const CHANNEL_ID = Deno.env.get('THINGSPEAK_CHANNEL_ID')!;
const READ_KEY = Deno.env.get('THINGSPEAK_READ_API_KEY')!;
const WRITE_KEY = Deno.env.get('THINGSPEAK_WRITE_API_KEY')!;
const DEVICE_TOKEN = Deno.env.get('THINGSPEAK_DEVICE_TOKEN')!;

const supabase = createClient(
  Deno.env.get('SUPABASE_URL')!,
  Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!,
);

// ── Field mapping ───────────────────────────────────────────────────────────
// field7 = device_timestamp (seconds since midnight from STM32 RTC)
const FIELD_MAP = {
  prediction: 'field1',
  confidence: 'field2',
  speed_kmh: 'field3',
  latitude: 'field4',
  longitude: 'field5',
  g_worst: 'field6',
  device_timestamp: 'field7', // ← seconds-since-midnight from STM32
} as const;

interface ThingSpeakFeedEntry {
  entry_id: number;
  created_at: string; // ISO string — ThingSpeak server time, always correct
  [key: string]: string | number | null;
}

Deno.serve(async (_req) => {
  try {
    // 1. Get last synced entry id
    const { data: syncState, error: syncErr } = await supabase
      .from('thingspeak_sync_state')
      .select('last_entry_id')
      .eq('channel_id', CHANNEL_ID)
      .maybeSingle();

    if (syncErr) throw syncErr;
    const lastEntryId = syncState?.last_entry_id ?? 0;

    // 2. Fetch feed entries from ThingSpeak (most recent up to 8000)
    const feedUrl =
      `https://api.thingspeak.com/channels/${CHANNEL_ID}/feeds.json` +
      `?api_key=${READ_KEY}&results=8000`;

    const feedRes = await fetch(feedUrl);
    if (!feedRes.ok) {
      throw new Error(`ThingSpeak feed fetch failed: ${feedRes.status}`);
    }
    const feedJson = await feedRes.json();
    const feeds: ThingSpeakFeedEntry[] = feedJson.feeds ?? [];

    // 3. Filter to only new entries
    const newEntries = feeds.filter((f) => f.entry_id > lastEntryId);

    if (newEntries.length === 0) {
      return jsonResponse({ message: 'No new entries', count: 0 });
    }

    // 4. Map + insert into Supabase
    //
    // KEY FIX: use `f.created_at` (ThingSpeak server timestamp — always a
    // real UTC datetime like "2026-06-16T05:20:01Z") as `recorded_at`.
    //
    // The STM32 sends seconds-since-midnight in field7. We store that raw
    // value in `device_timestamp` for reference, but we do NOT use it to
    // drive any timestamp columns because it has no date component.
    const rows = newEntries.map((f) => {
      const deviceSecStr = getField(f, 'device_timestamp');
      const deviceSec = toNum(deviceSecStr);

      // Build a proper device_timestamp by combining ThingSpeak's date
      // with the STM32's seconds-since-midnight, if field7 is present
      // and looks plausible (0–86399 seconds).
      let deviceTimestamp: string | null = null;
      if (deviceSec !== null && deviceSec >= 0 && deviceSec < 86400) {
        // Use ThingSpeak's date as the calendar date anchor
        const tsDate = new Date(f.created_at);
        const h = Math.floor(deviceSec / 3600);
        const m = Math.floor((deviceSec % 3600) / 60);
        const s = Math.floor(deviceSec % 60);
        tsDate.setUTCHours(h, m, s, 0);
        deviceTimestamp = tsDate.toISOString();
      }

      return {
        device_token: DEVICE_TOKEN,
        thingspeak_entry_id: f.entry_id,
        prediction: getField(f, 'prediction'),
        confidence: toNum(getField(f, 'confidence')),
        speed_kmh: toNum(getField(f, 'speed_kmh')),
        latitude: toNum(getField(f, 'latitude')),
        longitude: toNum(getField(f, 'longitude')),
        g_worst: toNum(getField(f, 'g_worst')),
        // ✅ Use ThingSpeak server time — always a real UTC datetime
        recorded_at: f.created_at,
        // ✅ Reconstructed device time (field7 seconds + TS date)
        device_timestamp: deviceTimestamp,
      };
    });

    const { error: insertErr } = await supabase
      .from('device_readings')
      .upsert(rows, { onConflict: 'device_token,thingspeak_entry_id' });

    if (insertErr) throw insertErr;

    const newLastEntryId = Math.max(...newEntries.map((f) => f.entry_id));

    // 5. Update sync state BEFORE clearing ThingSpeak, so if the clear
    //    fails we don't reprocess (upsert above is idempotent anyway).
    const { error: stateErr } = await supabase
      .from('thingspeak_sync_state')
      .upsert({
        channel_id: CHANNEL_ID,
        last_entry_id: newLastEntryId,
        last_synced_at: new Date().toISOString(),
      });
    if (stateErr) throw stateErr;

    // 6. Clear the ThingSpeak feed now that everything is safely in Supabase.
    const clearUrl =
      `https://api.thingspeak.com/channels/${CHANNEL_ID}/feeds.json` +
      `?api_key=${WRITE_KEY}`;

    const clearRes = await fetch(clearUrl, { method: 'DELETE' });
    const cleared = clearRes.ok;

    return jsonResponse({
      message: 'Synced',
      inserted: rows.length,
      lastEntryId: newLastEntryId,
      thingspeakCleared: cleared,
    });
  } catch (err) {
    console.error(err);
    return jsonResponse({ error: serializeError(err) }, 500);
  }
});

// ── Helpers ──────────────────────────────────────────────────────────────────

function serializeError(err: unknown): unknown {
  if (err instanceof Error) {
    return { name: err.name, message: err.message, stack: err.stack };
  }
  if (err && typeof err === 'object') {
    const { message, details, hint, code } = err as Record<string, unknown>;
    return { message, details, hint, code, raw: err };
  }
  return { value: String(err) };
}

function getField(
  entry: ThingSpeakFeedEntry,
  key: keyof typeof FIELD_MAP,
): string | null {
  const fieldKey = FIELD_MAP[key];
  const val = entry[fieldKey];
  return val === null || val === undefined ? null : String(val);
}

function toNum(val: string | null): number | null {
  if (val === null) return null;
  const n = Number(val);
  return Number.isNaN(n) ? null : n;
}

function jsonResponse(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { 'Content-Type': 'application/json' },
  });
}

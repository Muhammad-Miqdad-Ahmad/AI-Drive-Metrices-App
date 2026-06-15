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
// Adjust these to match how your STM32 actually posts to ThingSpeak fields.
const FIELD_MAP = {
  prediction: 'field1',
  confidence: 'field2',
  speed_kmh: 'field3',
  latitude: 'field4',
  longitude: 'field5',
  g_worst: 'field6',
} as const;

interface ThingSpeakFeedEntry {
  entry_id: number;
  created_at: string;
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
    const rows = newEntries.map((f) => ({
      device_token: DEVICE_TOKEN,
      thingspeak_entry_id: f.entry_id,
      prediction: getField(f, 'prediction'),
      confidence: toNum(getField(f, 'confidence')),
      speed_kmh: toNum(getField(f, 'speed_kmh')),
      latitude: toNum(getField(f, 'latitude')),
      longitude: toNum(getField(f, 'longitude')),
      g_worst: toNum(getField(f, 'g_worst')),
      recorded_at: f.created_at,
    }));

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
    //    NOTE: ThingSpeak's API only supports clearing the ENTIRE channel
    //    feed, not deleting individual entries by id/date.
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
    // Supabase/Postgrest errors are plain objects with these fields
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

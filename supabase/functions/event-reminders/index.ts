// Edge Function : rappels FCM planifiés (cron).
// - Veille (Europe/Paris) : tous les utilisateurs qui peuvent voir l’événement.
// - J-7 et J-3 : uniquement les personnes inscrites via « Je participe ».
//
// Auth : Authorization: Bearer <EVENT_REMINDERS_CRON_SECRET> (secret dédié, pas un JWT user).
// Secrets : FIREBASE_SERVICE_ACCOUNT, EVENT_REMINDERS_CRON_SECRET.

import { createClient } from "https://esm.sh/@supabase/supabase-js@2.49.1";
import { initializeApp, cert, getApps } from "npm:firebase-admin@12.0.0/app";
import { getMessaging } from "npm:firebase-admin@12.0.0/messaging";

const corsHeaders: Record<string, string> = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
};

type EventRow = {
  id: string;
  title: string;
  visibility: string;
  association_id: string | null;
  created_by: string | null;
  event_date?: string | null;
  location?: string | null;
  category?: string | null;
  associations?: { name: string } | null;
};

type ReminderKind =
  | "day_before_visible"
  | "participant_7d"
  | "participant_3d";

function categoryLabelFr(cat: string | undefined | null): string {
  const m: Record<string, string> = {
    soiree: "Soirée",
    afterwork: "Afterwork",
    journee: "Journée",
    vente_nourriture: "Vente de nourriture",
    sport: "Sport",
    culture: "Culture",
    concert: "Concert",
    autre: "Autre",
  };
  if (!cat) return "";
  return m[cat] ?? cat;
}

function formatEventDateFr(iso: string | null | undefined): string {
  if (!iso) return "";
  try {
    const d = new Date(iso);
    if (Number.isNaN(d.getTime())) return "";
    return new Intl.DateTimeFormat("fr-FR", {
      weekday: "long",
      day: "numeric",
      month: "long",
      hour: "2-digit",
      minute: "2-digit",
    }).format(d);
  } catch {
    return "";
  }
}

function initFirebase() {
  const raw = Deno.env.get("FIREBASE_SERVICE_ACCOUNT");
  if (!raw) throw new Error("FIREBASE_SERVICE_ACCOUNT manquant");
  const sa = JSON.parse(raw);
  if (!getApps().length) {
    initializeApp({ credential: cert(sa) });
  }
}

/** Tous les profils qui peuvent voir l’événement (rappel veille — pas d’exclusion du créateur). */
async function recipientUserIdsForVisible(
  supabase: ReturnType<typeof createClient>,
  event: EventRow,
): Promise<string[]> {
  const vis = event.visibility;

  if (vis === "public") {
    const { data, error } = await supabase.from("users").select("id");
    if (error) throw error;
    return (data ?? []).map((r: { id: string }) => r.id);
  }

  const aid = event.association_id;

  if (vis === "restricted") {
    if (!aid) {
      const { data, error } = await supabase.from("users").select("id").eq(
        "role",
        "admin",
      );
      if (error) throw error;
      return (data ?? []).map((r: { id: string }) => r.id);
    }
    const { data: admins, error: e1 } = await supabase.from("users").select(
      "id",
    ).eq("role", "admin");
    if (e1) throw e1;
    const { data: members, error: e2 } = await supabase.from("memberships")
      .select("user_id").eq("association_id", aid);
    if (e2) throw e2;
    const set = new Set<string>();
    for (const a of admins ?? []) set.add(a.id);
    for (const m of members ?? []) set.add(m.user_id);
    return [...set];
  }

  if (vis === "private") {
    const { data: admins, error: e1 } = await supabase.from("users").select(
      "id",
    ).eq("role", "admin");
    if (e1) throw e1;
    const { data: responsibles, error: e2 } = await supabase.from(
      "memberships",
    ).select("user_id").eq("role", "responsible");
    if (e2) throw e2;
    const set = new Set<string>();
    for (const a of admins ?? []) set.add(a.id);
    for (const r of responsibles ?? []) set.add(r.user_id);
    return [...set];
  }

  return [];
}

async function participantUserIds(
  supabase: ReturnType<typeof createClient>,
  eventId: string,
): Promise<string[]> {
  const { data, error } = await supabase.from("event_participations").select(
    "user_id",
  ).eq("event_id", eventId).eq("status", "going");
  if (error) throw error;
  const set = new Set<string>();
  for (const r of data ?? []) set.add((r as { user_id: string }).user_id);
  return [...set];
}

async function alreadySentUserIds(
  supabase: ReturnType<typeof createClient>,
  eventId: string,
  kind: ReminderKind,
): Promise<Set<string>> {
  const { data, error } = await supabase.from("event_push_reminders").select(
    "user_id",
  ).eq("event_id", eventId).eq("reminder_kind", kind);
  if (error) throw error;
  return new Set((data ?? []).map((r: { user_id: string }) => r.user_id));
}

function buildReminderNotification(
  event: EventRow,
  kind: ReminderKind,
): { title: string; body: string; dataKind: string } {
  const rawTitle = (event.title ?? "").trim() || "Événement";
  const asso = event.associations?.name?.trim();
  const when = formatEventDateFr(event.event_date);
  const loc = event.location?.trim();
  const cat = categoryLabelFr(event.category);

  if (kind === "day_before_visible") {
    const title = rawTitle.length > 58
      ? `Demain · ${rawTitle.slice(0, 55)}…`
      : `Demain · ${rawTitle}`;
    const bits: string[] = ["C’est demain ! Viens nombreux."];
    if (asso) bits.push(`Par ${asso}`);
    if (when) bits.push(when);
    if (loc) bits.push(loc.length > 40 ? `${loc.slice(0, 37)}…` : loc);
    if (cat) bits.push(cat);
    let body = bits.join(" · ");
    if (body.length > 200) body = `${body.slice(0, 199)}…`;
    return { title, body, dataKind: "reminder_day_before" };
  }

  if (kind === "participant_7d") {
    const title = rawTitle.length > 55
      ? `Dans 1 semaine · ${rawTitle.slice(0, 52)}…`
      : `Dans 1 semaine · ${rawTitle}`;
    const body =
      `Tu as indiqué vouloir participer. Rappel J-7 — ${rawTitle.length > 60 ? `${rawTitle.slice(0, 57)}…` : rawTitle}${when ? ` · ${when}` : ""}.`;
    return {
      title,
      body: body.length > 220 ? `${body.slice(0, 219)}…` : body,
      dataKind: "reminder_participant_7d",
    };
  }

  const title = rawTitle.length > 55
    ? `Dans 3 jours · ${rawTitle.slice(0, 52)}…`
    : `Dans 3 jours · ${rawTitle}`;
  const body =
    `Rappel : tu participes à cet événement — ${rawTitle.length > 70 ? `${rawTitle.slice(0, 67)}…` : rawTitle}${when ? ` · ${when}` : ""}.`;
  return {
    title,
    body: body.length > 220 ? `${body.slice(0, 219)}…` : body,
    dataKind: "reminder_participant_3d",
  };
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    const secret = Deno.env.get("EVENT_REMINDERS_CRON_SECRET");
    if (!secret || secret.length < 8) {
      console.error("event-reminders: EVENT_REMINDERS_CRON_SECRET manquant ou trop court");
      return new Response(
        JSON.stringify({ error: "Server misconfigured" }),
        { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } },
      );
    }

    const auth = req.headers.get("Authorization");
    const bearer = auth?.startsWith("Bearer ") ? auth.slice(7).trim() : "";
    if (bearer !== secret) {
      console.warn("event-reminders: unauthorized caller");
      return new Response(JSON.stringify({ error: "Unauthorized" }), {
        status: 401,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    const supabaseUrl = Deno.env.get("SUPABASE_URL")!;
    const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
    const supabase = createClient(supabaseUrl, serviceKey);

    const { data: pairs, error: rpcErr } = await supabase.rpc(
      "get_events_needing_reminders",
    );
    if (rpcErr) throw rpcErr;

    const rows = (pairs ?? []) as { event_id: string; reminder_kind: string }[];
    if (rows.length === 0) {
      return new Response(
        JSON.stringify({ processed: 0, sent: 0, message: "nothing due" }),
        { status: 200, headers: { ...corsHeaders, "Content-Type": "application/json" } },
      );
    }

    initFirebase();
    const messaging = getMessaging();

    let totalSent = 0;
    let processed = 0;

    for (const row of rows) {
      const eventId = row.event_id;
      const kind = row.reminder_kind as ReminderKind;
      processed++;

      const { data: event, error: evErr } = await supabase
        .from("events")
        .select(
          "id, title, visibility, association_id, created_by, event_date, location, category, associations(name)",
        )
        .eq("id", eventId)
        .maybeSingle();

      if (evErr) throw evErr;
      if (!event) continue;

      const ev = event as EventRow;

      let userIds: string[];
      if (kind === "day_before_visible") {
        userIds = await recipientUserIdsForVisible(supabase, ev);
      } else {
        userIds = await participantUserIds(supabase, eventId);
      }

      const skip = await alreadySentUserIds(supabase, eventId, kind);
      userIds = userIds.filter((id) => !skip.has(id));

      if (userIds.length === 0) continue;

      const { data: tokenRows, error: tokErr } = await supabase
        .from("user_fcm_tokens")
        .select("user_id, token")
        .in("user_id", userIds);

      if (tokErr) throw tokErr;
      const usersWithToken = new Set<string>();
      const tokenList: string[] = [];
      for (const r of tokenRows ?? []) {
        const tr = r as { user_id: string; token: string };
        usersWithToken.add(tr.user_id);
        tokenList.push(tr.token);
      }
      const tokens = [...new Set(tokenList)];
      if (tokens.length === 0) continue;

      const { title: notifTitle, body: notifBody, dataKind } =
        buildReminderNotification(ev, kind);

      const chunkSize = 400;
      let batchSent = 0;
      for (let i = 0; i < tokens.length; i += chunkSize) {
        const chunk = tokens.slice(i, i + chunkSize);
        const res = await messaging.sendEachForMulticast({
          tokens: chunk,
          notification: { title: notifTitle, body: notifBody },
          data: {
            event_id: ev.id,
            event_title: (ev.title ?? "").slice(0, 200),
            click_action: "FLUTTER_NOTIFICATION_CLICK",
            notify_kind: dataKind,
          },
          android: {
            priority: "high" as const,
            notification: {
              channelId: "eventsphere_high_importance",
            },
          },
        });
        batchSent += res.successCount;
      }

      totalSent += batchSent;

      const logRows = [...usersWithToken].map((user_id) => ({
        event_id: eventId,
        user_id,
        reminder_kind: kind,
      }));
      if (logRows.length > 0) {
        const { error: insErr } = await supabase.from("event_push_reminders").insert(
          logRows,
        );
        if (insErr) {
          console.error("event-reminders: log insert", insErr);
        }
      }
    }

    console.log(
      `event-reminders: pairs=${rows.length} processed=${processed} fcm≈${totalSent}`,
    );

    return new Response(
      JSON.stringify({
        pairs: rows.length,
        processed,
        sent: totalSent,
      }),
      { status: 200, headers: { ...corsHeaders, "Content-Type": "application/json" } },
    );
  } catch (e) {
    console.error(e);
    return new Response(
      JSON.stringify({ error: (e as Error).message ?? String(e) }),
      {
        status: 500,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      },
    );
  }
});

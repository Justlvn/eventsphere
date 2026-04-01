// Edge Function : envoie une notification FCM aux utilisateurs qui peuvent voir l'événement
// (même logique que PermissionService.canSeeEvent côté app).
// Secrets : SUPABASE_SERVICE_ROLE_KEY (auto), FIREBASE_SERVICE_ACCOUNT (JSON compte de service).

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
      weekday: "short",
      day: "numeric",
      month: "short",
      hour: "2-digit",
      minute: "2-digit",
    }).format(d);
  } catch {
    return "";
  }
}

/** Titre + texte affichés dans la barre de notification (limites FCM ~affichage). */
function buildNotificationContent(event: EventRow): { title: string; body: string } {
  const rawTitle = (event.title ?? "").trim() || "Nouvel événement";
  const isPrivate = event.visibility === "private";

  const titlePrefix = "Privé · ";
  let title: string;
  if (isPrivate) {
    const maxCore = Math.max(8, 65 - titlePrefix.length);
    const core =
      rawTitle.length > maxCore ? `${rawTitle.slice(0, maxCore - 1)}…` : rawTitle;
    title = `${titlePrefix}${core}`;
  } else {
    title = rawTitle.length > 65 ? `${rawTitle.slice(0, 62)}…` : rawTitle;
  }

  const bits: string[] = [];
  const asso = event.associations?.name?.trim();
  if (asso) bits.push(`Par ${asso}`);
  const cat = categoryLabelFr(event.category);
  if (cat) bits.push(cat);
  const when = formatEventDateFr(event.event_date);
  if (when) bits.push(when);
  const loc = event.location?.trim();
  if (loc) {
    bits.push(loc.length > 45 ? `${loc.slice(0, 42)}…` : loc);
  }

  const detailCore = bits.length > 0
    ? bits.join(" · ")
    : "Ouvre l’app pour voir les détails.";

  const privateBodyLead =
    "Événement privé — tu reçois cette alerte en tant que responsable ou admin. ";

  const bodySource = isPrivate ? `${privateBodyLead}${detailCore}` : detailCore;
  const maxBody = isPrivate ? 220 : 180;
  const body = bodySource.length > maxBody
    ? `${bodySource.slice(0, maxBody - 1)}…`
    : bodySource;

  return { title, body };
}

/** private < restricted < public (élargissement d’audience). */
function isVisibilityWidening(
  previous: string,
  current: string,
): boolean {
  if (previous === current) return false;
  if (previous === "private") {
    return current === "restricted" || current === "public";
  }
  if (previous === "restricted") return current === "public";
  return false;
}

function initFirebase() {
  const raw = Deno.env.get("FIREBASE_SERVICE_ACCOUNT");
  if (!raw) {
    throw new Error("FIREBASE_SERVICE_ACCOUNT manquant");
  }
  const sa = JSON.parse(raw);
  if (!getApps().length) {
    initializeApp({ credential: cert(sa) });
  }
}

async function recipientUserIds(
  supabase: ReturnType<typeof createClient>,
  event: EventRow,
  visibilityOverride?: string,
): Promise<string[]> {
  const vis = visibilityOverride ?? event.visibility;
  const creator = event.created_by;
  const exclude = (ids: string[]) =>
    creator ? ids.filter((id) => id !== creator) : ids;

  if (vis === "public") {
    const { data, error } = await supabase.from("users").select("id");
    if (error) throw error;
    return exclude((data ?? []).map((r: { id: string }) => r.id));
  }

  const aid = event.association_id;

  if (vis === "restricted") {
    if (!aid) {
      const { data, error } = await supabase.from("users").select("id").eq(
        "role",
        "admin",
      );
      if (error) throw error;
      return exclude((data ?? []).map((r: { id: string }) => r.id));
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
    return exclude([...set]);
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
    return exclude([...set]);
  }

  return [];
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    console.log(`notify-on-event: ${req.method} (content-length: ${req.headers.get("content-length") ?? "?"})`);

    const authHeader = req.headers.get("Authorization");
    if (!authHeader?.startsWith("Bearer ")) {
      console.warn("notify-on-event: missing or invalid Authorization header");
      return new Response(JSON.stringify({ error: "Unauthorized" }), {
        status: 401,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    const supabaseUrl = Deno.env.get("SUPABASE_URL")!;
    const anonKey = Deno.env.get("SUPABASE_ANON_KEY")!;
    const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;

    const supabaseUser = createClient(supabaseUrl, anonKey, {
      global: { headers: { Authorization: authHeader } },
    });
    const { data: { user }, error: authErr } = await supabaseUser.auth
      .getUser();
    if (authErr || !user) {
      console.warn(
        "notify-on-event: getUser failed",
        authErr?.message ?? "no user",
      );
      return new Response(JSON.stringify({ error: "Unauthorized" }), {
        status: 401,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    console.log(`notify-on-event: auth ok user=${user.id}`);

    const body = await req.json().catch(() => ({}));
    const eventId = body?.event_id as string | undefined;
    const previousVisibility = body?.previous_visibility as string | undefined;
    if (!eventId) {
      return new Response(JSON.stringify({ error: "event_id requis" }), {
        status: 400,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    const supabase = createClient(supabaseUrl, serviceKey);
    const { data: event, error: evErr } = await supabase
      .from("events")
      .select(
        "id, title, visibility, association_id, created_by, event_date, location, category, associations(name)",
      )
      .eq("id", eventId)
      .maybeSingle();

    if (evErr) throw evErr;
    if (!event) {
      return new Response(JSON.stringify({ error: "Événement introuvable" }), {
        status: 404,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    const { data: profile } = await supabase.from("users").select("role").eq(
      "id",
      user.id,
    ).maybeSingle();
    const isAdmin = profile?.role === "admin";
    const isCreator = event.created_by === user.id;
    if (!isAdmin && !isCreator) {
      console.warn(
        `notify-on-event: forbidden user=${user.id} event=${eventId}`,
      );
      return new Response(JSON.stringify({ error: "Forbidden" }), {
        status: 403,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    let userIds: string[];
    let visibilityWidened = false;

    if (previousVisibility && typeof previousVisibility === "string") {
      if (!isVisibilityWidening(previousVisibility, event.visibility)) {
        return new Response(
          JSON.stringify({ sent: 0, message: "skip: visibilité non élargie" }),
          {
            status: 200,
            headers: { ...corsHeaders, "Content-Type": "application/json" },
          },
        );
      }
      visibilityWidened = true;
      const before = await recipientUserIds(
        supabase,
        event as EventRow,
        previousVisibility,
      );
      const after = await recipientUserIds(supabase, event as EventRow);
      const beforeSet = new Set(before);
      userIds = after.filter((id) => !beforeSet.has(id));
    } else {
      userIds = await recipientUserIds(supabase, event as EventRow);
    }

    if (userIds.length === 0) {
      return new Response(JSON.stringify({ sent: 0, message: "no recipients" }), {
        status: 200,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    const { data: tokenRows, error: tokErr } = await supabase
      .from("user_fcm_tokens")
      .select("token")
      .in("user_id", userIds);

    if (tokErr) throw tokErr;
    const tokens = [...new Set((tokenRows ?? []).map((r: { token: string }) => r.token))];
    if (tokens.length === 0) {
      console.log(
        `notify-on-event: no FCM tokens for ${userIds.length} recipient user ids`,
      );
      return new Response(JSON.stringify({ sent: 0, message: "no tokens" }), {
        status: 200,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    initFirebase();
    const messaging = getMessaging();

    const ev = event as EventRow;
    const { title: notifTitle, body: notifBody } = buildNotificationContent(ev);

    // FCM limite ~500 par requête multicast ; on découpe.
    const chunkSize = 400;
    let sent = 0;
    for (let i = 0; i < tokens.length; i += chunkSize) {
      const chunk = tokens.slice(i, i + chunkSize);
      const res = await messaging.sendEachForMulticast({
        tokens: chunk,
        notification: { title: notifTitle, body: notifBody },
        data: {
          event_id: event.id,
          event_title: (ev.title ?? "").slice(0, 200),
          click_action: "FLUTTER_NOTIFICATION_CLICK",
          notify_kind: visibilityWidened ? "visibility_widened" : "created",
        },
        android: {
          priority: "high" as const,
          notification: {
            // Même id que côté Flutter (`push_notification_service.dart`).
            channelId: "eventsphere_high_importance",
          },
        },
      });
      sent += res.successCount;
    }

    console.log(
      `notify-on-event: FCM sent=${sent} recipients=${userIds.length} tokens=${tokens.length}`,
    );

    return new Response(JSON.stringify({ sent, recipients: userIds.length }), {
      status: 200,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
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

// お知らせ用 Googleカレンダー同期関数
//
// 方式A-2（ゲスト招待方式）:
//   システム用Googleアカウントのカレンダーに予定を1件作成し、
//   お知らせの配信対象者を「ゲスト（招待者）」として追加する。
//   Google が各ゲストの個人カレンダーに予定を反映する。
//   visibility='specific' の場合は選ばれた議員だけをゲストにするため、
//   特定配信のお知らせが対象外の議員のカレンダーに出ることはない。
//
// 必要な Supabase Secrets:
//   CALENDAR_CLIENT_ID     (未設定なら GMAIL_CLIENT_ID を流用)
//   CALENDAR_CLIENT_SECRET (未設定なら GMAIL_CLIENT_SECRET を流用)
//   CALENDAR_REFRESH_TOKEN (calendar スコープで取得したリフレッシュトークン。必須)
//   CALENDAR_ID            (未設定なら "primary")
//
// 呼び出し元の認可:
//   この関数はシステム用Googleアカウントの権限でカレンダーを直接操作するため、
//   RLSを経由しない。呼び出し元のSupabase JWTを検証し、
//   upsert/delete は 管理者(is_portal_admin) または そのお知らせの作成者本人のみ
//     （作成者の場合は announcementNo 必須。eventId はそのお知らせの予定と一致すること。
//       ゲストは現職の名簿メンバーに限る）
//   respond はログイン済みユーザーが「自分の出欠」を反映する場合のみ（管理者は代理可）。

import { createClient } from "https://esm.sh/@supabase/supabase-js@2.107.0";

const CORS_HEADERS = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS"
};

const MAX_ATTENDEES = 300;
const MAX_TEXT_LENGTH = 8000;
const EMAIL_PATTERN = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
const RFC3339_PATTERN = /^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}[+-]\d{2}:\d{2}$/;

type CalendarSyncPayload = {
  action?: "upsert" | "delete" | "respond";
  announcementNo?: number;
  eventId?: string;
  sendUpdates?: "all" | "none" | "externalOnly";
  event?: {
    summary?: string;
    description?: string;
    location?: string;
    startDateTime?: string;
    endDateTime?: string;
    attendees?: string[];
    reminderMinutes?: number[];
  };
  attendeeEmail?: string;
  status?: "attend" | "absent" | "pending";
};

const RESPONSE_STATUS_BY_PORTAL_STATUS: Record<string, string> = {
  attend: "accepted",
  absent: "declined",
  pending: "tentative"
};

function jsonResponse(status: number, body: Record<string, unknown>) {
  return new Response(JSON.stringify(body), {
    status,
    headers: {
      ...CORS_HEADERS,
      "Content-Type": "application/json; charset=utf-8"
    }
  });
}

function clampText(value: unknown): string {
  return String(value ?? "").slice(0, MAX_TEXT_LENGTH);
}

function sanitizeEmails(list: unknown): string[] {
  if (!Array.isArray(list)) return [];
  const cleaned = list
    .map((email) => String(email ?? "").trim().toLowerCase())
    .filter((email) => EMAIL_PATTERN.test(email));
  return Array.from(new Set(cleaned)).slice(0, MAX_ATTENDEES);
}

function sanitizeReminders(list: unknown): { method: string; minutes: number }[] {
  const source = Array.isArray(list) && list.length > 0 ? list : [60, 30];
  const minutes = source
    .map((value) => Number(value))
    .filter((value) => Number.isFinite(value) && value >= 0 && value <= 40320)
    .map((value) => Math.floor(value));
  return Array.from(new Set(minutes)).slice(0, 5).map((m) => ({ method: "popup", minutes: m }));
}

async function getCalendarAccessToken() {
  const clientId = Deno.env.get("CALENDAR_CLIENT_ID") || Deno.env.get("GMAIL_CLIENT_ID") || "";
  const clientSecret = Deno.env.get("CALENDAR_CLIENT_SECRET") || Deno.env.get("GMAIL_CLIENT_SECRET") || "";
  const refreshToken = Deno.env.get("CALENDAR_REFRESH_TOKEN") || "";

  if (!clientId || !clientSecret || !refreshToken) {
    throw new Error("Missing environment variables: CALENDAR_CLIENT_ID/SECRET (or GMAIL_*) and CALENDAR_REFRESH_TOKEN");
  }

  const response = await fetch("https://oauth2.googleapis.com/token", {
    method: "POST",
    headers: { "Content-Type": "application/x-www-form-urlencoded" },
    body: new URLSearchParams({
      client_id: clientId,
      client_secret: clientSecret,
      refresh_token: refreshToken,
      grant_type: "refresh_token"
    })
  });

  if (!response.ok) {
    const errorText = await response.text();
    throw new Error(`Failed to refresh Calendar token: ${errorText}`);
  }

  const data = await response.json() as { access_token?: string };
  if (!data.access_token) {
    throw new Error("Calendar access token not found in refresh response");
  }
  return data.access_token;
}

type AuthorizedCaller = {
  email: string;
  isAdmin: boolean;
  // deno-lint-ignore no-explicit-any
  client: any;
};

async function getAuthorizedCaller(req: Request): Promise<AuthorizedCaller | null> {
  const authHeader = req.headers.get("Authorization") || req.headers.get("authorization") || "";
  const token = authHeader.replace(/^Bearer\s+/i, "").trim();
  if (!token) {
    return null;
  }

  const supabaseUrl = Deno.env.get("SUPABASE_URL") || "";
  const supabaseAnonKey = Deno.env.get("SUPABASE_ANON_KEY") || "";
  if (!supabaseUrl || !supabaseAnonKey) {
    return null;
  }

  const supabase = createClient(supabaseUrl, supabaseAnonKey, {
    global: { headers: { Authorization: `Bearer ${token}` } }
  });

  const { data: userData, error: userError } = await supabase.auth.getUser(token);
  if (userError || !userData?.user) {
    return null;
  }

  const { data: isAdminData, error: adminError } = await supabase.rpc("is_portal_admin");
  if (adminError) {
    return null;
  }

  return {
    email: String(userData.user.email || "").trim().toLowerCase(),
    isAdmin: Boolean(isAdminData),
    client: supabase
  };
}

// 管理者以外が upsert/delete する場合: 呼び出し者がそのお知らせの作成者本人であること。
// お知らせは呼び出し者のJWT（RLS適用）で読むので、見えないお知らせは操作できない。
async function verifyAnnouncementOwner(
  caller: AuthorizedCaller,
  announcementNo: number,
  eventId: string
): Promise<string | null> {
  if (!Number.isInteger(announcementNo) || announcementNo <= 0) {
    return "announcementNo が必要です。";
  }
  const { data, error } = await caller.client
    .from("announcements")
    .select("no,created_by_email,google_calendar_event_id")
    .eq("no", announcementNo)
    .maybeSingle();
  if (error || !data) {
    return "対象のお知らせが見つかりません。";
  }
  const ownerEmail = String(data.created_by_email || "").trim().toLowerCase();
  if (!ownerEmail || ownerEmail !== caller.email) {
    return "このお知らせの作成者または管理者のみ操作できます。";
  }
  const linkedEventId = String(data.google_calendar_event_id || "").trim();
  if (eventId && eventId !== linkedEventId) {
    return "指定された予定はこのお知らせのものではありません。";
  }
  return null;
}

// 管理者以外が招待できるゲストは現職の名簿メンバーに限る
async function filterCurrentMembers(caller: AuthorizedCaller, emails: string[]): Promise<string[]> {
  if (emails.length === 0) return [];
  const { data, error } = await caller.client
    .from("member_directory")
    .select("email")
    .eq("is_current", true);
  if (error || !Array.isArray(data)) return [];
  const memberSet = new Set(data.map((row: { email?: string }) => String(row.email || "").trim().toLowerCase()));
  return emails.filter((email) => memberSet.has(email));
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { status: 200, headers: CORS_HEADERS });
  }
  if (req.method !== "POST") {
    return jsonResponse(405, { ok: false, error: "Method not allowed" });
  }

  let payload: CalendarSyncPayload;
  try {
    payload = (await req.json()) as CalendarSyncPayload;
  } catch (_error) {
    return jsonResponse(400, { ok: false, error: "Invalid JSON payload" });
  }

  const action = payload.action === "delete" ? "delete" : payload.action === "respond" ? "respond" : "upsert";

  const caller = await getAuthorizedCaller(req);
  if (!caller) {
    return jsonResponse(401, { ok: false, error: "認証が必要です。ログインし直してください。" });
  }
  const eventId = String(payload.eventId || "").trim();
  if ((action === "upsert" || action === "delete") && !caller.isAdmin) {
    const ownerError = await verifyAnnouncementOwner(caller, Number(payload.announcementNo), eventId);
    if (ownerError) {
      return jsonResponse(403, { ok: false, error: ownerError });
    }
  }
  if (action === "respond" && !caller.isAdmin) {
    const requested = String(payload.attendeeEmail || "").trim().toLowerCase();
    if (!caller.email || requested !== caller.email) {
      return jsonResponse(403, { ok: false, error: "自分の出欠のみ反映できます。" });
    }
  }
  const calendarId = Deno.env.get("CALENDAR_ID") || "primary";
  const sendUpdates = payload.sendUpdates === "none" || payload.sendUpdates === "externalOnly"
    ? payload.sendUpdates
    : action === "respond" ? "none" : "all";

  const encodedCalendarId = encodeURIComponent(calendarId);

  let accessToken = "";
  try {
    accessToken = await getCalendarAccessToken();
  } catch (error) {
    return jsonResponse(502, {
      ok: false,
      error: "Calendar token refresh error",
      detail: error instanceof Error ? error.message : String(error)
    });
  }

  // --- 削除 ---
  if (action === "delete") {
    if (!eventId) {
      return jsonResponse(400, { ok: false, error: "eventId is required for delete" });
    }
    const url = `https://www.googleapis.com/calendar/v3/calendars/${encodedCalendarId}/events/${encodeURIComponent(eventId)}?sendUpdates=${sendUpdates}`;
    const response = await fetch(url, {
      method: "DELETE",
      headers: { "Authorization": `Bearer ${accessToken}` }
    });
    // 既に削除済み(404/410)は成功扱い
    if (!response.ok && response.status !== 404 && response.status !== 410) {
      const errorText = await response.text();
      return jsonResponse(502, { ok: false, error: "Calendar API error (delete)", detail: errorText });
    }
    return jsonResponse(200, { ok: true, deleted: true });
  }

  // --- 出欠回答の反映（ポータル→カレンダー） ---
  if (action === "respond") {
    if (!eventId) {
      return jsonResponse(400, { ok: false, error: "eventId is required for respond" });
    }
    const attendeeEmail = String(payload.attendeeEmail || "").trim().toLowerCase();
    const googleStatus = RESPONSE_STATUS_BY_PORTAL_STATUS[String(payload.status || "")];
    if (!EMAIL_PATTERN.test(attendeeEmail) || !googleStatus) {
      return jsonResponse(400, { ok: false, error: "attendeeEmail and a valid status are required" });
    }

    const getUrl = `https://www.googleapis.com/calendar/v3/calendars/${encodedCalendarId}/events/${encodeURIComponent(eventId)}`;
    const getResponse = await fetch(getUrl, {
      headers: { "Authorization": `Bearer ${accessToken}` }
    });
    if (!getResponse.ok) {
      const errorText = await getResponse.text();
      return jsonResponse(502, { ok: false, error: "Calendar API error (get)", detail: errorText });
    }

    const eventData = await getResponse.json() as { attendees?: { email?: string; responseStatus?: string }[] };
    const attendees = Array.isArray(eventData.attendees) ? eventData.attendees : [];
    const target = attendees.find((a) => String(a.email || "").trim().toLowerCase() === attendeeEmail);
    if (!target) {
      return jsonResponse(404, { ok: false, error: "attendee not found on this event" });
    }
    target.responseStatus = googleStatus;

    const patchUrl = `https://www.googleapis.com/calendar/v3/calendars/${encodedCalendarId}/events/${encodeURIComponent(eventId)}?sendUpdates=${sendUpdates}`;
    const patchResponse = await fetch(patchUrl, {
      method: "PATCH",
      headers: {
        "Authorization": `Bearer ${accessToken}`,
        "Content-Type": "application/json"
      },
      body: JSON.stringify({ attendees })
    });
    if (!patchResponse.ok) {
      const errorText = await patchResponse.text();
      return jsonResponse(502, { ok: false, error: "Calendar API error (respond)", detail: errorText });
    }

    return jsonResponse(200, { ok: true, eventId, responseStatus: googleStatus });
  }

  // --- 作成 / 更新 ---
  const ev = payload.event || {};
  const summary = clampText(ev.summary).trim() || "お知らせ";
  const description = clampText(ev.description);
  const location = clampText(ev.location).trim();
  const startDateTime = String(ev.startDateTime || "").trim();
  const endDateTime = String(ev.endDateTime || "").trim();
  const sanitizedAttendees = sanitizeEmails(ev.attendees);
  const attendees = caller.isAdmin ? sanitizedAttendees : await filterCurrentMembers(caller, sanitizedAttendees);
  const reminders = sanitizeReminders(ev.reminderMinutes);

  if (!RFC3339_PATTERN.test(startDateTime) || !RFC3339_PATTERN.test(endDateTime)) {
    return jsonResponse(400, { ok: false, error: "startDateTime/endDateTime must be RFC3339 with timezone offset" });
  }

  const eventBody: Record<string, unknown> = {
    summary,
    description,
    start: { dateTime: startDateTime, timeZone: "Asia/Tokyo" },
    end: { dateTime: endDateTime, timeZone: "Asia/Tokyo" },
    attendees: attendees.map((email) => ({ email })),
    guestsCanSeeOtherGuests: false,
    guestsCanModify: false,
    guestsCanInviteOthers: false,
    reminders: { useDefault: false, overrides: reminders }
  };
  if (location) {
    eventBody.location = location;
  }

  const isUpdate = !!eventId;
  const url = isUpdate
    ? `https://www.googleapis.com/calendar/v3/calendars/${encodedCalendarId}/events/${encodeURIComponent(eventId)}?sendUpdates=${sendUpdates}`
    : `https://www.googleapis.com/calendar/v3/calendars/${encodedCalendarId}/events?sendUpdates=${sendUpdates}`;

  const response = await fetch(url, {
    method: isUpdate ? "PATCH" : "POST",
    headers: {
      "Authorization": `Bearer ${accessToken}`,
      "Content-Type": "application/json"
    },
    body: JSON.stringify(eventBody)
  });

  if (!response.ok) {
    const errorText = await response.text();
    return jsonResponse(502, { ok: false, error: "Calendar API error (upsert)", detail: errorText });
  }

  const data = await response.json() as { id?: string; htmlLink?: string };
  return jsonResponse(200, {
    ok: true,
    eventId: data.id || eventId || null,
    htmlLink: data.htmlLink || null,
    attendeeCount: attendees.length
  });
});

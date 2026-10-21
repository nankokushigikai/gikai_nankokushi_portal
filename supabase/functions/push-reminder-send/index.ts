// お知らせの開始前通知(Push)を送る関数
// ・呼び出し元は pg_cron の push_reminder_tick() だけ(通知すべき分がある時だけ呼ばれる)
// ・ヘッダー x-push-cron-secret が secrets の PUSH_CRON_SECRET と一致しない呼び出しは拒否する
// ・送り先と本文の元データは DB関数 claim_push_reminders()(service_role のみ実行可)から受け取る
// ・宛先が無効(404/410)になった端末は登録を削除する
// deploy: supabase functions deploy push-reminder-send --no-verify-jwt
//   (JWTではなく合言葉で検証するため。合言葉が無い呼び出しは何もしない)
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.107.0";
import webpush from "npm:web-push@3.6.7";

type ClaimRow = {
  announcement_no: number;
  stage: number;
  remind_minutes: number;
  title: string | null;
  start_time: string | null;
  subscription_id: number;
  endpoint: string;
  p256dh: string;
  auth_key: string;
};

const PORTAL_TITLE = "南国市議会ポータル";

function jsonResponse(status: number, body: Record<string, unknown>) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { "Content-Type": "application/json; charset=utf-8" }
  });
}

// 長さの違いで中身を推測されないよう、固定時間で比較する
function safeEqual(a: string, b: string) {
  const enc = new TextEncoder();
  const x = enc.encode(a);
  const y = enc.encode(b);
  if (x.length !== y.length || x.length === 0) return false;
  let diff = 0;
  for (let i = 0; i < x.length; i++) diff |= x[i] ^ y[i];
  return diff === 0;
}

function buildBody(row: ClaimRow) {
  const title = String(row.title || "お知らせ").slice(0, 80);
  const start = row.start_time ? String(row.start_time).slice(0, 5) : "";
  const timeText = start ? `（${start}〜）` : "";
  const prefix = row.remind_minutes >= 1440 ? "明日開始" : "まもなく開始";
  return `${prefix}：${title}${timeText}`;
}

Deno.serve(async (req) => {
  if (req.method !== "POST") {
    return jsonResponse(405, { ok: false, error: "method not allowed" });
  }

  const expectedSecret = Deno.env.get("PUSH_CRON_SECRET") || "";
  const givenSecret = req.headers.get("x-push-cron-secret") || "";
  if (!safeEqual(givenSecret, expectedSecret)) {
    return jsonResponse(401, { ok: false, error: "unauthorized" });
  }

  const supabaseUrl = Deno.env.get("SUPABASE_URL") || "";
  const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") || "";
  const vapidPublic = Deno.env.get("VAPID_PUBLIC_KEY") || "";
  const vapidPrivate = Deno.env.get("VAPID_PRIVATE_KEY") || "";
  const vapidSubject = Deno.env.get("VAPID_SUBJECT") || "";
  if (!supabaseUrl || !serviceRoleKey || !vapidPublic || !vapidPrivate || !vapidSubject) {
    return jsonResponse(500, { ok: false, error: "server not configured" });
  }

  webpush.setVapidDetails(vapidSubject, vapidPublic, vapidPrivate);
  const supabase = createClient(supabaseUrl, serviceRoleKey, {
    auth: { persistSession: false, autoRefreshToken: false }
  });

  const { data, error } = await supabase.rpc("claim_push_reminders");
  if (error) {
    console.error("claim_push_reminders failed:", error.message);
    return jsonResponse(500, { ok: false, error: "claim failed" });
  }

  const rows = (data || []) as ClaimRow[];
  let sent = 0;
  let removed = 0;
  let failed = 0;

  for (const row of rows) {
    const payload = JSON.stringify({
      title: PORTAL_TITLE,
      body: buildBody(row),
      url: "index.html",
      tag: `announcement-${row.announcement_no}-${row.stage}`
    });
    try {
      await webpush.sendNotification(
        { endpoint: row.endpoint, keys: { p256dh: row.p256dh, auth: row.auth_key } },
        payload,
        { TTL: 600, urgency: "high" }
      );
      sent += 1;
      await supabase.from("push_subscriptions")
        .update({ last_sent_at: new Date().toISOString(), last_error: null })
        .eq("id", row.subscription_id);
    } catch (e) {
      const statusCode = Number((e as { statusCode?: number })?.statusCode || 0);
      if (statusCode === 404 || statusCode === 410) {
        removed += 1;
        await supabase.from("push_subscriptions").delete().eq("id", row.subscription_id);
      } else {
        failed += 1;
        await supabase.from("push_subscriptions")
          .update({ last_error: `${statusCode || "error"} ${new Date().toISOString()}` })
          .eq("id", row.subscription_id);
      }
    }
  }

  return jsonResponse(200, { ok: true, targets: rows.length, sent, removed, failed });
});

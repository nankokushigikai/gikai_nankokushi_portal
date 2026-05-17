const CORS_HEADERS = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS"
};

const textEncoder = new TextEncoder();

type NotifyPayload = {
  toEmail?: string;
  memberId?: string;
  memberName?: string;
  mode?: "created" | "updated" | string;
  loginUrl?: string;
  subject?: string;
  body?: string;
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

function encodeMimeWord(value: string) {
  const bytes = textEncoder.encode(value);
  let binary = "";
  for (const byte of bytes) {
    binary += String.fromCharCode(byte);
  }
  return `=?UTF-8?B?${btoa(binary)}?=`;
}

function toBase64Url(value: Uint8Array) {
  let binary = "";
  for (const byte of value) {
    binary += String.fromCharCode(byte);
  }

  return btoa(binary)
    .replace(/\+/g, "-")
    .replace(/\//g, "_")
    .replace(/=+$/g, "");
}

function buildRawMessage({
  fromEmail,
  fromName,
  toEmail,
  subject,
  body
}: {
  fromEmail: string;
  fromName: string;
  toEmail: string;
  subject: string;
  body: string;
}) {
  const headers = [
    `From: ${encodeMimeWord(fromName)} <${fromEmail}>`,
    `To: <${toEmail}>`,
    `Subject: ${encodeMimeWord(subject)}`,
    "MIME-Version: 1.0",
    "Content-Type: text/plain; charset=UTF-8",
    "Content-Transfer-Encoding: 8bit"
  ];

  const raw = `${headers.join("\r\n")}\r\n\r\n${body}`;
  return toBase64Url(textEncoder.encode(raw));
}

async function getGmailAccessToken() {
  const clientId = Deno.env.get("GMAIL_CLIENT_ID") || "";
  const clientSecret = Deno.env.get("GMAIL_CLIENT_SECRET") || "";
  const refreshToken = Deno.env.get("GMAIL_REFRESH_TOKEN") || "";

  if (!clientId || !clientSecret || !refreshToken) {
    throw new Error("Missing environment variables: GMAIL_CLIENT_ID, GMAIL_CLIENT_SECRET or GMAIL_REFRESH_TOKEN");
  }

  const response = await fetch("https://oauth2.googleapis.com/token", {
    method: "POST",
    headers: {
      "Content-Type": "application/x-www-form-urlencoded"
    },
    body: new URLSearchParams({
      client_id: clientId,
      client_secret: clientSecret,
      refresh_token: refreshToken,
      grant_type: "refresh_token"
    })
  });

  if (!response.ok) {
    const errorText = await response.text();
    throw new Error(`Failed to refresh Gmail token: ${errorText}`);
  }

  const data = await response.json() as { access_token?: string };
  if (!data.access_token) {
    throw new Error("Gmail access token not found in refresh response");
  }

  return data.access_token;
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { status: 200, headers: CORS_HEADERS });
  }

  if (req.method !== "POST") {
    return jsonResponse(405, { ok: false, error: "Method not allowed" });
  }

  const fromEmail = Deno.env.get("GMAIL_FROM_EMAIL") || "";
  const fromName = Deno.env.get("GMAIL_FROM_NAME") || "南国市議会DXポータル";

  if (!fromEmail) {
    return jsonResponse(500, {
      ok: false,
      error: "Missing environment variable: GMAIL_FROM_EMAIL"
    });
  }

  let payload: NotifyPayload;
  try {
    payload = (await req.json()) as NotifyPayload;
  } catch (_error) {
    return jsonResponse(400, { ok: false, error: "Invalid JSON payload" });
  }

  const toEmail = String(payload.toEmail || "").trim().toLowerCase();
  if (!toEmail) {
    return jsonResponse(400, { ok: false, error: "toEmail is required" });
  }

  const modeText = payload.mode === "updated" ? "変更" : "登録";
  const memberName = String(payload.memberName || "ご利用者様").trim() || "ご利用者様";
  const loginUrl = String(payload.loginUrl || "").trim();

  const subject =
    String(payload.subject || "").trim() ||
    `【南国市議会DXポータル】プロフィール情報${modeText}のお知らせ`;

  const body =
    String(payload.body || "").trim() ||
    [
      `${memberName} 様`,
      "",
      `南国市議会DXポータルのプロフィール情報を${modeText}しました。`,
      "ログインは以下のURLをご利用ください。",
      loginUrl,
      "",
      "このメールはシステムから自動送信されています。"
    ].join("\n");

  let accessToken = "";
  try {
    accessToken = await getGmailAccessToken();
  } catch (error) {
    return jsonResponse(502, {
      ok: false,
      error: "Gmail token refresh error",
      detail: error instanceof Error ? error.message : String(error)
    });
  }

  const raw = buildRawMessage({
    fromEmail,
    fromName,
    toEmail,
    subject,
    body
  });

  const gmailResponse = await fetch("https://gmail.googleapis.com/gmail/v1/users/me/messages/send", {
    method: "POST",
    headers: {
      "Authorization": `Bearer ${accessToken}`,
      "Content-Type": "application/json"
    },
    body: JSON.stringify({ raw })
  });

  if (!gmailResponse.ok) {
    const errorText = await gmailResponse.text();
    return jsonResponse(502, {
      ok: false,
      error: "Gmail API error",
      detail: errorText
    });
  }

  const data = await gmailResponse.json() as { id?: string };
  return jsonResponse(200, {
    ok: true,
    gmailMessageId: data.id || null,
    toEmail,
    memberId: payload.memberId || ""
  });
});

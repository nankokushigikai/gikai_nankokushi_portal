const CORS_HEADERS = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS"
};

const textEncoder = new TextEncoder();

type MailNoticePayload = {
  toEmails?: string[];
  subject?: string;
  body?: string;
  senderName?: string;
  attachmentNames?: string[];
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
  toEmails,
  subject,
  body
}: {
  fromEmail: string;
  fromName: string;
  toEmails: string[];
  subject: string;
  body: string;
}) {
  const bcc = toEmails.join(",");
  const headers = [
    `From: ${encodeMimeWord(fromName)} <${fromEmail}>`,
    "To: <undisclosed-recipients:;>",
    `Bcc: ${bcc}`,
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
  const defaultFromName = Deno.env.get("GMAIL_FROM_NAME") || "南国市議会DXポータル";

  if (!fromEmail) {
    return jsonResponse(500, {
      ok: false,
      error: "Missing environment variable: GMAIL_FROM_EMAIL"
    });
  }

  let payload: MailNoticePayload;
  try {
    payload = (await req.json()) as MailNoticePayload;
  } catch (_error) {
    return jsonResponse(400, { ok: false, error: "Invalid JSON payload" });
  }

  const toEmails = Array.from(new Set((payload.toEmails || [])
    .map((email) => String(email || "").trim().toLowerCase())
    .filter((email) => !!email)));

  if (!toEmails.length) {
    return jsonResponse(400, { ok: false, error: "toEmails is required" });
  }

  const subject = String(payload.subject || "").trim() || "【南国市議会DXポータル】お知らせ";
  const senderName = String(payload.senderName || "").trim() || defaultFromName;

  const bodyBase = String(payload.body || "").trim() || "お知らせをご確認ください。";
  const attachmentNames = (payload.attachmentNames || [])
    .map((name) => String(name || "").trim())
    .filter((name) => !!name);
  const body = attachmentNames.length > 0
    ? `${bodyBase}\n\n添付ファイル:\n${attachmentNames.map((name) => `- ${name}`).join("\n")}`
    : bodyBase;

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
    fromName: senderName,
    toEmails,
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
    recipientCount: toEmails.length
  });
});

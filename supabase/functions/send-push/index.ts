// Edge Function: send FCM push when message (to user) or job assignment (to officer).
// Set secrets: FIREBASE_PROJECT_ID, FIREBASE_SERVICE_ACCOUNT_JSON (full JSON string).
// Trigger via Database Webhooks: messages (INSERT), scrap_submissions (UPDATE).

import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const FCM_SEND_URL = (projectId: string) =>
  `https://fcm.googleapis.com/v1/projects/${projectId}/messages:send`;

interface WebhookPayload {
  type: "INSERT" | "UPDATE";
  table: string;
  record: Record<string, unknown>;
  old_record?: Record<string, unknown>;
}

interface FCMTokenRow {
  token: string;
}

async function getGoogleAccessToken(serviceAccountJson: string): Promise<string> {
  const sa = JSON.parse(serviceAccountJson);
  const now = Math.floor(Date.now() / 1000);
  const payload = {
    iss: sa.client_email,
    sub: sa.client_email,
    aud: "https://oauth2.googleapis.com/token",
    iat: now,
    exp: now + 3600,
    scope: "https://www.googleapis.com/auth/firebase.messaging",
  };
  const header = { alg: "RS256", typ: "JWT" };
  const encodedHeader = btoa(JSON.stringify(header)).replace(/=/g, "").replace(/\+/g, "-").replace(/\//g, "_");
  const encodedPayload = btoa(JSON.stringify(payload)).replace(/=/g, "").replace(/\+/g, "-").replace(/\//g, "_");
  const signatureInput = `${encodedHeader}.${encodedPayload}`;

  const key = await crypto.subtle.importKey(
    "pkcs8",
    Uint8Array.from(atob(sa.private_key.replace(/-----BEGIN PRIVATE KEY-----|-----END PRIVATE KEY-----|\s/g, "")), (c) => c.charCodeAt(0)),
    { name: "RSASSA-PKCS1-v1_5", hash: "SHA-256" },
    false,
    ["sign"]
  );

  const signature = await crypto.subtle.sign(
    "RSASSA-PKCS1-v1_5",
    key,
    new TextEncoder().encode(signatureInput)
  );
  const encodedSignature = btoa(String.fromCharCode(...new Uint8Array(signature)))
    .replace(/=/g, "")
    .replace(/\+/g, "-")
    .replace(/\//g, "_");
  const jwt = `${signatureInput}.${encodedSignature}`;

  const res = await fetch("https://oauth2.googleapis.com/token", {
    method: "POST",
    headers: { "Content-Type": "application/x-www-form-urlencoded" },
    body: new URLSearchParams({
      grant_type: "urn:ietf:params:oauth:grant-type:jwt-bearer",
      assertion: jwt,
    }),
  });
  if (!res.ok) throw new Error(`OAuth failed: ${await res.text()}`);
  const data = await res.json();
  return data.access_token;
}

async function sendFCM(
  projectId: string,
  accessToken: string,
  token: string,
  title: string,
  body: string
): Promise<void> {
  const res = await fetch(FCM_SEND_URL(projectId), {
    method: "POST",
    headers: {
      Authorization: `Bearer ${accessToken}`,
      "Content-Type": "application/json",
    },
    body: JSON.stringify({
      message: {
        token,
        notification: { title, body },
        android: { priority: "high", notification: { channel_id: "greenhaul_updates" } },
      },
    }),
  });
  if (!res.ok) {
    console.error("FCM send failed:", await res.text());
  }
}

Deno.serve(async (req) => {
  try {
    const projectId = Deno.env.get("FIREBASE_PROJECT_ID");
    const serviceAccountJson = Deno.env.get("FIREBASE_SERVICE_ACCOUNT_JSON");
    if (!projectId || !serviceAccountJson) {
      return new Response(JSON.stringify({ error: "FCM not configured" }), { status: 500 });
    }

    const payload = (await req.json()) as WebhookPayload;
    const supabase = createClient(
      Deno.env.get("SUPABASE_URL") ?? "",
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? ""
    );

    let tokens: { token: string }[] = [];
    let title = "";
    let body = "";

    if (payload.table === "messages" && payload.type === "INSERT") {
      const record = payload.record as { submission_id?: string; is_admin_message?: boolean };
      if (!record.is_admin_message) return new Response("OK", { status: 200 });
      const { data: sub } = await supabase
        .from("scrap_submissions")
        .select("user_id")
        .eq("id", record.submission_id)
        .single();
      const userId = sub?.user_id;
      if (!userId) return new Response("OK", { status: 200 });
      const { data: rows } = await supabase.from("fcm_tokens").select("token").eq("user_id", userId);
      tokens = (rows ?? []) as FCMTokenRow[];
      title = "New message";
      body = "Message from team";
    } else if (payload.table === "scrap_submissions" && payload.type === "UPDATE") {
      const record = payload.record as { assigned_officer_id?: string };
      const oldRecord = payload.old_record as { assigned_officer_id?: string } | undefined;
      const newId = record.assigned_officer_id;
      const oldId = oldRecord?.assigned_officer_id;
      if (!newId || newId === oldId) return new Response("OK", { status: 200 });
      const { data: rows } = await supabase.from("fcm_tokens").select("token").eq("field_officer_id", newId);
      tokens = (rows ?? []) as FCMTokenRow[];
      title = "Job assigned";
      body = "You have been assigned a new job";
    } else {
      return new Response("OK", { status: 200 });
    }

    if (tokens.length === 0) return new Response("OK", { status: 200 });

    const accessToken = await getGoogleAccessToken(serviceAccountJson);
    for (const row of tokens) {
      await sendFCM(projectId, accessToken, row.token, title, body);
    }
    return new Response("OK", { status: 200 });
  } catch (e) {
    console.error(e);
    return new Response(JSON.stringify({ error: String(e) }), { status: 500 });
  }
});

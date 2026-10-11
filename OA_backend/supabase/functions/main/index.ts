// OA Manager v1 - Main Edge Function Router
// self-hosted edge-runtime (--main-service 단일 진입점)에서
// cross-function 라우팅이 불안정하여 핫경로 함수는 여기에 inline.

import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient, type SupabaseClient } from "https://esm.sh/@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

const adminGroupRoles = new Set(["admin", "operator1", "operator2"]);

function jsonResponse(body: unknown, status: number): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
}

/**
 * The service client is deliberately used only after the caller's JWT has been
 * verified.  Do not replace this with an anon-key check: the anon key is public
 * by design and is not proof that a caller is an OA administrator.
 */
async function requireAdminGroup(req: Request, supabase: SupabaseClient<any>): Promise<Response | null> {
  const authorization = req.headers.get("authorization");
  const accessToken = authorization?.match(/^Bearer\s+(.+)$/i)?.[1];
  if (!accessToken) {
    return jsonResponse({ error: "인증 토큰이 필요합니다" }, 401);
  }

  const { data: authData, error: authError } = await supabase.auth.getUser(accessToken);
  if (authError || !authData.user) {
    return jsonResponse({ error: "유효하지 않은 인증 토큰입니다" }, 401);
  }

  const { data: profile, error: profileError } = await supabase
    .from("users")
    .select("role")
    .eq("auth_uid", authData.user.id)
    .maybeSingle();

  if (profileError || !profile || !adminGroupRoles.has(profile.role)) {
    return jsonResponse({ error: "관리자 권한이 필요합니다" }, 403);
  }

  return null;
}

// ─── send-notification handler (inline) ─────────────────────────────────────
// body: { asset_uid?, type?, title, body?, record?: boolean }
//   record=false → notifications 테이블에 이력 저장 생략 (트리거에서 호출 시 무한루프 방지)
async function sendNotificationHandler(req: Request): Promise<Response> {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  if (req.method !== "POST") {
    return jsonResponse({ error: "Method not allowed" }, 405);
  }

  try {
    const supabase = createClient(
      Deno.env.get("SUPABASE_URL")!,
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
    );

    const authorizationError = await requireAdminGroup(req, supabase);
    if (authorizationError) return authorizationError;

    const body = await req.json() as {
      asset_uid?: unknown;
      type?: unknown;
      title?: unknown;
      body?: unknown;
      record?: unknown;
    };
    const { asset_uid, type, title, body: msgBody, record = true } = body;

    if (typeof title !== "string" || !title.trim() || title.length > 200) {
      return jsonResponse({ error: "알림 제목은 1~200자로 입력하세요" }, 400);
    }
    if (asset_uid != null && (typeof asset_uid !== "string" || asset_uid.length > 100)) {
      return jsonResponse({ error: "유효하지 않은 자산번호입니다" }, 400);
    }
    if (msgBody != null && (typeof msgBody !== "string" || msgBody.length > 2_000)) {
      return jsonResponse({ error: "알림 본문은 2,000자 이하여야 합니다" }, 400);
    }
    if (type != null && typeof type !== "string") {
      return jsonResponse({ error: "유효하지 않은 알림 유형입니다" }, 400);
    }
    if (typeof record !== "boolean") {
      return jsonResponse({ error: "유효하지 않은 record 값입니다" }, 400);
    }

    let query = supabase.from("device_tokens").select("fcm_token, asset_uid");
    if (asset_uid) query = query.eq("asset_uid", asset_uid);
    const { data: tokens, error: tokenError } = await query;

    if (tokenError) {
      return new Response(
        JSON.stringify({ error: "알림 대상 조회에 실패했습니다" }),
        { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } },
      );
    }

    const firebaseKeyStr = Deno.env.get("FIREBASE_SERVICE_ACCOUNT_KEY");
    let sentCount = 0;
    let fcmSkipped = false;

    if (!firebaseKeyStr) {
      // FCM 키 미설정 — 이력만 저장하고 종료 (운영 환경에서 키 주입 시 자동 동작)
      fcmSkipped = true;
    } else if (tokens && tokens.length > 0) {
      const firebaseKey = JSON.parse(firebaseKeyStr);
      const projectId = firebaseKey.project_id;

      // Google OAuth2 JWT
      const now = Math.floor(Date.now() / 1000);
      const header = btoa(JSON.stringify({ alg: "RS256", typ: "JWT" }));
      const payload = btoa(JSON.stringify({
        iss: firebaseKey.client_email,
        scope: "https://www.googleapis.com/auth/firebase.messaging",
        aud: "https://oauth2.googleapis.com/token",
        iat: now,
        exp: now + 3600,
      }));
      const keyData = firebaseKey.private_key
        .replace("-----BEGIN PRIVATE KEY-----", "")
        .replace("-----END PRIVATE KEY-----", "")
        .replace(/\n/g, "");
      const binaryKey = Uint8Array.from(atob(keyData), (c) => c.charCodeAt(0));
      const cryptoKey = await crypto.subtle.importKey(
        "pkcs8", binaryKey,
        { name: "RSASSA-PKCS1-v1_5", hash: "SHA-256" },
        false, ["sign"],
      );
      const sig = await crypto.subtle.sign(
        "RSASSA-PKCS1-v1_5", cryptoKey,
        new TextEncoder().encode(`${header}.${payload}`),
      );
      const jwt = `${header}.${payload}.${btoa(String.fromCharCode(...new Uint8Array(sig)))}`;

      const tokenResp = await fetch("https://oauth2.googleapis.com/token", {
        method: "POST",
        headers: { "Content-Type": "application/x-www-form-urlencoded" },
        body: `grant_type=urn:ietf:params:oauth:grant-type:jwt-bearer&assertion=${jwt}`,
      });
      const { access_token } = await tokenResp.json();

      for (const tok of tokens) {
        const r = await fetch(
          `https://fcm.googleapis.com/v1/projects/${projectId}/messages:send`,
          {
            method: "POST",
            headers: {
              "Authorization": `Bearer ${access_token}`,
              "Content-Type": "application/json",
            },
            body: JSON.stringify({
              message: {
                token: tok.fcm_token,
                notification: { title: title.trim(), body: msgBody ?? "" },
                data: { type: type ?? "general", asset_uid: tok.asset_uid ?? "" },
              },
            }),
          },
        );
        if (r.ok) sentCount++;
      }
    }

    // 이력 저장 (record=false면 생략 — DB 트리거로 호출된 경우)
    if (record && tokens && tokens.length > 0) {
      await supabase.from("notifications").insert(
        tokens.map((t: { asset_uid: string; fcm_token: string }) => ({
          asset_uid: t.asset_uid,
          type: type ?? "general",
          title: title.trim(),
          body: msgBody,
        })),
      );
    }

    return new Response(
      JSON.stringify({
        success: true,
        sent_count: sentCount,
        total: tokens?.length ?? 0,
        fcm_skipped: fcmSkipped,
      }),
      { headers: { ...corsHeaders, "Content-Type": "application/json" } },
    );
  } catch (err) {
    return new Response(
      JSON.stringify({ error: "알림 발송 처리 중 오류가 발생했습니다" }),
      { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } },
    );
  }
}

// ─── 라우터 ─────────────────────────────────────────────────────────────────
serve((req: Request) => {
  const url = new URL(req.url);
  const path = url.pathname.replace(/^\/+/, "").replace(/\/+$/, "");

  if (path === "" || path === "health") {
    return new Response(JSON.stringify({ status: "ok" }), {
      headers: { "content-type": "application/json" },
    });
  }

  const fnName = path.split("/")[0];
  switch (fnName) {
    case "send-notification":
      return sendNotificationHandler(req);
    default:
      return new Response(`Function '${fnName}' not found`, { status: 404 });
  }
});

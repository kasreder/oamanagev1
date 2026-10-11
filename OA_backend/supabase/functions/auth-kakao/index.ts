// OA Manager v1 - Kakao sign-in boundary
//
// This is intentionally public because it turns a Kakao access token into an
// OA session.  It must remain separately rate-limited at Kong and may never
// accept a client-provided employee ID, Auth UID, or redirect URL.

import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

const maxRequestBytes = 8_192;

type KakaoPayload = { kakao_token?: unknown };

function jsonResponse(body: unknown, status: number): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
}

async function readKakaoPayload(req: Request): Promise<KakaoPayload | Response> {
  const contentLengthHeader = req.headers.get("content-length");
  if (contentLengthHeader !== null) {
    const contentLength = Number(contentLengthHeader);
    if (!Number.isSafeInteger(contentLength) || contentLength < 0) {
      return jsonResponse({ error: "유효하지 않은 요청 크기입니다" }, 400);
    }
    if (contentLength > maxRequestBytes) {
      return jsonResponse({ error: "요청이 너무 큽니다" }, 413);
    }
  }
  if (!req.headers.get("content-type")?.toLowerCase().includes("application/json")) {
    return jsonResponse({ error: "application/json 요청만 허용됩니다" }, 415);
  }

  const reader = req.body?.getReader();
  if (!reader) return jsonResponse({ error: "유효한 JSON 요청이 필요합니다" }, 400);

  const chunks: Uint8Array[] = [];
  let receivedBytes = 0;
  try {
    while (true) {
      const { done, value } = await reader.read();
      if (done) break;
      receivedBytes += value.byteLength;
      if (receivedBytes > maxRequestBytes) {
        await reader.cancel();
        return jsonResponse({ error: "요청이 너무 큽니다" }, 413);
      }
      chunks.push(value);
    }

    const bytes = new Uint8Array(receivedBytes);
    let offset = 0;
    for (const chunk of chunks) {
      bytes.set(chunk, offset);
      offset += chunk.byteLength;
    }
    const parsed: unknown = JSON.parse(new TextDecoder().decode(bytes));
    if (!parsed || typeof parsed !== "object" || Array.isArray(parsed)) {
      return jsonResponse({ error: "유효한 JSON 요청이 필요합니다" }, 400);
    }
    return parsed as KakaoPayload;
  } catch (_) {
    return jsonResponse({ error: "유효한 JSON 요청이 필요합니다" }, 400);
  } finally {
    reader.releaseLock();
  }
}

serve(async (req: Request) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }
  if (req.method !== "POST") {
    return jsonResponse({ error: "Method not allowed" }, 405);
  }

  try {
    // The Function itself has no browser session to authenticate yet.  Limit
    // its public input before calling Kakao, and accept only JSON.
    const payload = await readKakaoPayload(req);
    if (payload instanceof Response) return payload;

    const kakaoToken = payload.kakao_token;
    if (
      typeof kakaoToken !== "string"
      || !kakaoToken.trim()
      || kakaoToken.length > 4_096
    ) {
      return jsonResponse({ error: "유효한 카카오 토큰이 필요합니다" }, 400);
    }

    // Kakao is the identity proof.  A valid Kakao ID alone is insufficient:
    // it must map to a pre-approved OA profile below.
    const kakaoRes = await fetch("https://kapi.kakao.com/v2/user/me", {
      headers: { Authorization: `Bearer ${kakaoToken.trim()}` },
    });
    if (!kakaoRes.ok) {
      console.error("Kakao API error:", kakaoRes.status);
      return jsonResponse({ error: "카카오 토큰 검증에 실패했습니다" }, 401);
    }

    const kakaoUser = await kakaoRes.json() as { id?: unknown };
    const kakaoId = typeof kakaoUser.id === "string" || typeof kakaoUser.id === "number"
      ? String(kakaoUser.id)
      : "";
    if (!/^\d+$/.test(kakaoId)) {
      return jsonResponse({ error: "카카오 토큰 검증에 실패했습니다" }, 401);
    }

    const supabaseAdmin = createClient(
      Deno.env.get("SUPABASE_URL")!,
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
      { auth: { autoRefreshToken: false, persistSession: false } },
    );

    // Only a profile provisioned by an administrator may receive a session.
    const { data: employee, error: employeeError } = await supabaseAdmin
      .from("users")
      .select("auth_uid, employee_id")
      .eq("sns_id", kakaoId)
      .eq("auth_provider", "kakao")
      .maybeSingle();
    if (employeeError || !employee) {
      return jsonResponse({ error: "로그인 권한이 없습니다" }, 403);
    }
    if (typeof employee.auth_uid !== "string" || !employee.auth_uid) {
      // Do not create/link auth.users from a public request.  A master admin
      // must provision the mapping first, preventing public account lifecycle
      // changes and trigger-conflict account takeover paths.
      return jsonResponse({ error: "관리자에게 카카오 계정 연결을 요청하세요" }, 403);
    }

    // Resolve the exact existing Auth user rather than deriving an email from
    // employee_id.  This prevents a mismatched ID from minting a magic link
    // for another (or a newly created) account.
    const { data: authUserData, error: authUserError } =
      await supabaseAdmin.auth.admin.getUserById(employee.auth_uid);
    const linkedEmail = authUserData.user?.email?.trim();
    if (authUserError || !linkedEmail) {
      console.error("Kakao linked Auth user lookup failed:", authUserError);
      return jsonResponse({ error: "로그인 권한이 없습니다" }, 403);
    }

    // generateLink + verifyOtp never accepts a client redirect URL.  It issues
    // a session only for the existing, already-linked Auth account.
    const { data: sessionData, error: sessionError } =
      await supabaseAdmin.auth.admin.generateLink({
        type: "magiclink",
        email: linkedEmail,
      });
    if (sessionError) {
      console.error("Kakao session link generation failed:", sessionError);
      return jsonResponse({ error: "세션 생성에 실패했습니다" }, 500);
    }

    const { data: verifyData, error: verifyError } =
      await supabaseAdmin.auth.verifyOtp({
        token_hash: sessionData.properties.hashed_token,
        type: "magiclink",
      });
    if (verifyError || !verifyData.session) {
      console.error("Kakao session issue failed:", verifyError);
      return jsonResponse({ error: "토큰 발급에 실패했습니다" }, 500);
    }

    // The app already fetches its profile after setting the session.  Do not
    // duplicate employee PII in this public endpoint response.
    return jsonResponse({
      access_token: verifyData.session.access_token,
      refresh_token: verifyData.session.refresh_token,
      token_type: "Bearer",
      expires_in: verifyData.session.expires_in,
    }, 200);
  } catch (err) {
    console.error("auth-kakao unexpected error:", err);
    return jsonResponse({ error: "서버 내부 오류가 발생했습니다" }, 500);
  }
});

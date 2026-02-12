// OA Manager v1 - auth-kakao Edge Function
// 카카오 OAuth 토큰을 검증하고 Supabase Auth 세션을 발급합니다.

import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

serve(async (req: Request) => {
  // CORS preflight
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  // POST 메서드만 허용
  if (req.method !== "POST") {
    return new Response(
      JSON.stringify({ error: "Method not allowed" }),
      { status: 405, headers: { ...corsHeaders, "Content-Type": "application/json" } },
    );
  }

  try {
    // ── 1. 요청 파싱 ────────────────────────────────────────────
    const { kakao_token } = await req.json();

    if (!kakao_token || typeof kakao_token !== "string") {
      return new Response(
        JSON.stringify({ error: "kakao_token is required" }),
        { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } },
      );
    }

    // ── 2. 카카오 API로 토큰 검증 ───────────────────────────────
    const kakaoRes = await fetch("https://kapi.kakao.com/v2/user/me", {
      headers: { Authorization: `Bearer ${kakao_token}` },
    });

    if (!kakaoRes.ok) {
      const kakaoErr = await kakaoRes.text();
      console.error("Kakao API error:", kakaoRes.status, kakaoErr);
      return new Response(
        JSON.stringify({ error: "카카오 토큰 검증에 실패했습니다" }),
        { status: 401, headers: { ...corsHeaders, "Content-Type": "application/json" } },
      );
    }

    const kakaoUser = await kakaoRes.json();
    const kakaoId = String(kakaoUser.id);

    if (!kakaoId) {
      return new Response(
        JSON.stringify({ error: "카카오 사용자 ID를 확인할 수 없습니다" }),
        { status: 401, headers: { ...corsHeaders, "Content-Type": "application/json" } },
      );
    }

    // ── 3. Supabase Admin 클라이언트 생성 ────────────────────────
    const supabaseUrl = Deno.env.get("SUPABASE_URL")!;
    const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;

    const supabaseAdmin = createClient(supabaseUrl, serviceRoleKey, {
      auth: {
        autoRefreshToken: false,
        persistSession: false,
      },
    });

    // ── 4. users 테이블에서 sns_id + auth_provider='kakao'로 사원 찾기
    const { data: employee, error: employeeError } = await supabaseAdmin
      .from("users")
      .select("*")
      .eq("sns_id", kakaoId)
      .eq("auth_provider", "kakao")
      .single();

    if (employeeError || !employee) {
      return new Response(
        JSON.stringify({ error: "등록되지 않은 사용자입니다" }),
        { status: 404, headers: { ...corsHeaders, "Content-Type": "application/json" } },
      );
    }

    // ── 5. Auth 계정 확인/생성 후 토큰 발급 ──────────────────────
    let authUid = employee.auth_uid;

    // auth_uid가 없으면 Auth 계정을 새로 생성
    if (!authUid) {
      const email = `${employee.employee_id}@oamanager.internal`;

      const { data: newAuthUser, error: createError } =
        await supabaseAdmin.auth.admin.createUser({
          email,
          email_confirm: true,
          user_metadata: {
            employee_id: employee.employee_id,
            employee_name: employee.employee_name,
            auth_provider: "kakao",
            sns_id: kakaoId,
          },
        });

      if (createError) {
        // 이미 존재하는 이메일이면 조회
        const { data: existingUsers } =
          await supabaseAdmin.auth.admin.listUsers();
        const existing = existingUsers?.users?.find(
          (u: { email?: string }) => u.email === email,
        );

        if (existing) {
          authUid = existing.id;
        } else {
          console.error("Auth user creation failed:", createError);
          return new Response(
            JSON.stringify({ error: "인증 계정 생성에 실패했습니다" }),
            { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } },
          );
        }
      } else {
        authUid = newAuthUser.user.id;
      }

      // users 테이블에 auth_uid 연결
      await supabaseAdmin
        .from("users")
        .update({ auth_uid: authUid })
        .eq("id", employee.id);
    }

    // ── 6. 서비스키로 Auth 토큰(세션) 발급 ──────────────────────
    // generateLink를 사용하여 magiclink를 생성하고, 이를 통해 세션을 발급
    // 또는 admin.generateLink 대신 서비스 역할로 직접 세션 생성
    const { data: sessionData, error: sessionError } =
      await supabaseAdmin.auth.admin.generateLink({
        type: "magiclink",
        email: `${employee.employee_id}@oamanager.internal`,
      });

    if (sessionError) {
      console.error("Session generation failed:", sessionError);
      return new Response(
        JSON.stringify({ error: "세션 생성에 실패했습니다" }),
        { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } },
      );
    }

    // OTP 해시를 사용해 실제 세션(토큰) 발급
    const { data: verifyData, error: verifyError } =
      await supabaseAdmin.auth.verifyOtp({
        token_hash: sessionData.properties.hashed_token,
        type: "magiclink",
      });

    if (verifyError || !verifyData.session) {
      console.error("OTP verification failed:", verifyError);
      return new Response(
        JSON.stringify({ error: "토큰 발급에 실패했습니다" }),
        { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } },
      );
    }

    // ── 7. 프론트엔드 기대 형식으로 응답 ────────────────────────
    const response = {
      access_token: verifyData.session.access_token,
      refresh_token: verifyData.session.refresh_token,
      token_type: "Bearer",
      expires_in: verifyData.session.expires_in,
      user: {
        id: employee.id,
        employee_id: employee.employee_id,
        employee_name: employee.employee_name,
        employment_type: employee.employment_type,
        organization_hq: employee.organization_hq,
        organization_dept: employee.organization_dept,
        organization_team: employee.organization_team,
        work_building: employee.work_building,
        work_floor: employee.work_floor,
      },
    };

    return new Response(JSON.stringify(response), {
      status: 200,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  } catch (err) {
    console.error("auth-kakao unexpected error:", err);
    return new Response(
      JSON.stringify({ error: "서버 내부 오류가 발생했습니다" }),
      { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } },
    );
  }
});

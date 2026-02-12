// OA Manager v1 - dashboard-stats Edge Function
// 홈 화면 대시보드 상단 카드에 필요한 집계 통계를 반환합니다.
// 응답: { total_assets, inspection_rate, unverified_count, expiring_count }

import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "GET, OPTIONS",
};

serve(async (req: Request) => {
  // CORS preflight
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  // GET 메서드만 허용
  if (req.method !== "GET") {
    return new Response(
      JSON.stringify({ error: "Method not allowed" }),
      { status: 405, headers: { ...corsHeaders, "Content-Type": "application/json" } },
    );
  }

  try {
    // ── Supabase 클라이언트 생성 ────────────────────────────────
    // 서비스 역할 키를 사용하여 RLS 우회 (통계 집계에 전체 데이터 필요)
    const supabaseUrl = Deno.env.get("SUPABASE_URL")!;
    const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;

    const supabase = createClient(supabaseUrl, serviceRoleKey, {
      auth: {
        autoRefreshToken: false,
        persistSession: false,
      },
    });

    // ── 1. total_assets: 총 자산 수 ─────────────────────────────
    const { count: totalAssets, error: totalError } = await supabase
      .from("assets")
      .select("*", { count: "exact", head: true });

    if (totalError) {
      console.error("total_assets query error:", totalError);
      throw totalError;
    }

    // ── 2. inspection_rate: 실사 완료율 (%) ─────────────────────
    // 완료 기준: inspection_building, inspection_floor,
    //           inspection_position, inspection_photo, signature_image 모두 NOT NULL
    //
    // 실사 완료된 asset_id 목록 조회 (자산당 하나라도 완료 실사가 있으면 완료)
    const { data: completedInspections, error: inspectionError } =
      await supabase
        .from("asset_inspections")
        .select("asset_id")
        .not("inspection_building", "is", null)
        .not("inspection_floor", "is", null)
        .not("inspection_position", "is", null)
        .not("inspection_photo", "is", null)
        .not("signature_image", "is", null);

    if (inspectionError) {
      console.error("inspection_rate query error:", inspectionError);
      throw inspectionError;
    }

    // 완료된 고유 자산 수 계산
    const completedAssetIds = new Set(
      (completedInspections ?? []).map(
        (row: { asset_id: number }) => row.asset_id,
      ),
    );
    const completedCount = completedAssetIds.size;

    const total = totalAssets ?? 0;
    const inspectionRate =
      total > 0 ? Math.round((completedCount / total) * 1000) / 10 : 0;

    // ── 3. unverified_count: 실사 완료건이 없는 자산 수 ──────────
    const unverifiedCount = total - completedCount;

    // ── 4. expiring_count: 만료 임박 자산 수 (D-7 이내) ──────────
    // supply_type IN ('렌탈','대여') AND supply_end_date BETWEEN now AND now+7days
    const now = new Date();
    const sevenDaysLater = new Date(
      now.getTime() + 7 * 24 * 60 * 60 * 1000,
    );

    const nowISO = now.toISOString();
    const sevenDaysLaterISO = sevenDaysLater.toISOString();

    const { count: expiringCount, error: expiringError } = await supabase
      .from("assets")
      .select("*", { count: "exact", head: true })
      .in("supply_type", ["렌탈", "대여"])
      .gte("supply_end_date", nowISO)
      .lte("supply_end_date", sevenDaysLaterISO);

    if (expiringError) {
      console.error("expiring_count query error:", expiringError);
      throw expiringError;
    }

    // ── 응답 반환 ───────────────────────────────────────────────
    const response = {
      total_assets: total,
      inspection_rate: inspectionRate,
      unverified_count: unverifiedCount,
      expiring_count: expiringCount ?? 0,
    };

    return new Response(JSON.stringify(response), {
      status: 200,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  } catch (err) {
    console.error("dashboard-stats unexpected error:", err);
    return new Response(
      JSON.stringify({ error: "통계 조회 중 오류가 발생했습니다" }),
      { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } },
    );
  }
});

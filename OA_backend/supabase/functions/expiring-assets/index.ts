// OA Manager v1 - expiring-assets Edge Function
// supply_type이 '렌탈' 또는 '대여'이고 supply_end_date가 7일 이내인
// 만료 임박 자산의 상세 목록을 반환합니다.

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
    const supabaseUrl = Deno.env.get("SUPABASE_URL")!;
    const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;

    const supabase = createClient(supabaseUrl, serviceRoleKey, {
      auth: {
        autoRefreshToken: false,
        persistSession: false,
      },
    });

    // ── RPC 호출 시도: get_expiring_assets() ────────────────────
    // DB에 RPC 함수가 존재하면 사용하고, 없으면 직접 쿼리로 대체
    const { data: rpcData, error: rpcError } = await supabase.rpc(
      "get_expiring_assets",
    );

    if (!rpcError && rpcData) {
      // RPC 함수가 정상 작동하면 결과를 그대로 반환
      return new Response(JSON.stringify(rpcData), {
        status: 200,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    // ── RPC 함수가 없는 경우: 직접 쿼리 (fallback) ──────────────
    if (rpcError) {
      console.warn(
        "get_expiring_assets RPC not available, falling back to direct query:",
        rpcError.message,
      );
    }

    const now = new Date();
    const sevenDaysLater = new Date(
      now.getTime() + 7 * 24 * 60 * 60 * 1000,
    );

    const nowISO = now.toISOString();
    const sevenDaysLaterISO = sevenDaysLater.toISOString();

    const { data: assets, error: queryError } = await supabase
      .from("assets")
      .select("id, asset_uid, name, supply_type, supply_end_date")
      .in("supply_type", ["렌탈", "대여"])
      .not("supply_end_date", "is", null)
      .gte("supply_end_date", nowISO)
      .lte("supply_end_date", sevenDaysLaterISO)
      .order("supply_end_date", { ascending: true });

    if (queryError) {
      console.error("expiring-assets query error:", queryError);
      throw queryError;
    }

    // D-day 계산 추가
    const today = new Date();
    today.setHours(0, 0, 0, 0);

    const result = (assets ?? []).map(
      (asset: {
        id: number;
        asset_uid: string;
        name: string | null;
        supply_type: string;
        supply_end_date: string;
      }) => {
        const endDate = new Date(asset.supply_end_date);
        endDate.setHours(0, 0, 0, 0);
        const diffMs = endDate.getTime() - today.getTime();
        const dDay = Math.ceil(diffMs / (1000 * 60 * 60 * 24));

        return {
          id: asset.id,
          asset_uid: asset.asset_uid,
          name: asset.name,
          supply_type: asset.supply_type,
          supply_end_date: asset.supply_end_date,
          d_day: dDay,
        };
      },
    );

    return new Response(JSON.stringify(result), {
      status: 200,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  } catch (err) {
    console.error("expiring-assets unexpected error:", err);
    return new Response(
      JSON.stringify({ error: "만료 임박 자산 조회 중 오류가 발생했습니다" }),
      { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } },
    );
  }
});

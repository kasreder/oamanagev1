// OA Manager v1 - Main Edge Function Router
// Edge Runtime 엔트리포인트: 각 함수로 요청을 라우팅합니다.

import { serve } from "https://deno.land/std@0.168.0/http/server.ts";

serve(async (req: Request) => {
  const url = new URL(req.url);
  const path = url.pathname;

  // /function-name 형태의 경로를 각 함수로 라우팅
  // Edge Runtime이 자동으로 처리하므로 여기서는 health check만 제공
  if (path === "/" || path === "/health") {
    return new Response(JSON.stringify({ status: "ok" }), {
      headers: { "content-type": "application/json" },
    });
  }

  return new Response("Not found", { status: 404 });
});

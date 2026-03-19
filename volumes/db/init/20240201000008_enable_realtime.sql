-- OA Manager v1
-- 10.1 Realtime 활성화

ALTER PUBLICATION supabase_realtime ADD TABLE public.assets;
ALTER PUBLICATION supabase_realtime ADD TABLE public.asset_inspections;

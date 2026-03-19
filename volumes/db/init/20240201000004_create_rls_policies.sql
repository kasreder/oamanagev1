-- OA Manager v1
-- 5.1~5.5 Row Level Security 정책

-- 5.1 모든 테이블 RLS 활성화
ALTER TABLE public.users ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.assets ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.asset_inspections ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.drawings ENABLE ROW LEVEL SECURITY;

-- 5.2 users 정책
CREATE POLICY "users_select" ON public.users
  FOR SELECT TO anon, authenticated
  USING (true);

CREATE POLICY "users_update_own" ON public.users
  FOR UPDATE TO authenticated
  USING (auth_uid = auth.uid())
  WITH CHECK (auth_uid = auth.uid());

-- 5.3 assets 정책
CREATE POLICY "assets_select" ON public.assets
  FOR SELECT TO anon, authenticated
  USING (true);

CREATE POLICY "assets_insert" ON public.assets
  FOR INSERT TO authenticated
  WITH CHECK (true);

CREATE POLICY "assets_update" ON public.assets
  FOR UPDATE TO authenticated
  USING (true)
  WITH CHECK (true);

CREATE POLICY "assets_delete" ON public.assets
  FOR DELETE TO authenticated
  USING (
    NOT EXISTS (
      SELECT 1 FROM public.asset_inspections
      WHERE asset_id = assets.id
    )
  );

-- 5.4 asset_inspections 정책
CREATE POLICY "inspections_select" ON public.asset_inspections
  FOR SELECT TO anon, authenticated
  USING (true);

CREATE POLICY "inspections_insert" ON public.asset_inspections
  FOR INSERT TO authenticated
  WITH CHECK (true);

CREATE POLICY "inspections_update" ON public.asset_inspections
  FOR UPDATE TO authenticated
  USING (
    COALESCE((auth.jwt() ->> 'is_admin')::boolean, false)
    OR NOT (
      inspection_building IS NOT NULL
      AND inspection_floor IS NOT NULL
      AND inspection_position IS NOT NULL
      AND inspection_photo IS NOT NULL
      AND signature_image IS NOT NULL
    )
  )
  WITH CHECK (
    COALESCE((auth.jwt() ->> 'is_admin')::boolean, false)
    OR NOT (
      inspection_building IS NOT NULL
      AND inspection_floor IS NOT NULL
      AND inspection_position IS NOT NULL
      AND inspection_photo IS NOT NULL
      AND signature_image IS NOT NULL
    )
  );

CREATE POLICY "inspections_delete" ON public.asset_inspections
  FOR DELETE TO authenticated
  USING (true);

-- 5.5 drawings 정책
CREATE POLICY "drawings_select" ON public.drawings
  FOR SELECT TO anon, authenticated
  USING (true);

CREATE POLICY "drawings_insert" ON public.drawings
  FOR INSERT TO authenticated
  WITH CHECK (true);

CREATE POLICY "drawings_update" ON public.drawings
  FOR UPDATE TO authenticated
  USING (true)
  WITH CHECK (true);

CREATE POLICY "drawings_delete" ON public.drawings
  FOR DELETE TO authenticated
  USING (true);

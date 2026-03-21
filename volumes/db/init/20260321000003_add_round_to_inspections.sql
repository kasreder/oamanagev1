-- asset_inspections에 라운드(차수) 참조 추가
ALTER TABLE public.asset_inspections
  ADD COLUMN IF NOT EXISTS round_id bigint REFERENCES public.inspection_rounds(id);

-- 실사 UPDATE RLS 수정:
-- - 관리자 그룹: 항상 수정 가능
-- - 일반 사용자: 미완료 + 라운드가 active일 때만 수정 가능
DROP POLICY IF EXISTS "inspections_update" ON public.asset_inspections;
CREATE POLICY "inspections_update" ON public.asset_inspections
  FOR UPDATE TO authenticated
  USING (
    public.is_admin_group()
    OR (
      -- 미완료 건만 수정 가능
      NOT (
        inspection_building IS NOT NULL
        AND inspection_floor IS NOT NULL
        AND inspection_position IS NOT NULL
        AND inspection_photo IS NOT NULL
        AND signature_image IS NOT NULL
      )
      -- 라운드가 없거나 active인 경우만
      AND (
        round_id IS NULL
        OR EXISTS (
          SELECT 1 FROM public.inspection_rounds
          WHERE id = round_id AND status = 'active'
        )
      )
    )
  )
  WITH CHECK (true);

-- 실사 INSERT RLS 수정: 기존 정책 유지 (authenticated만)
-- 변경 없음

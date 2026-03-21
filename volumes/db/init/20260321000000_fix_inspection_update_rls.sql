-- Fix: 실사 완료 시 마지막 필드(서명/사진) 업데이트가 RLS WITH CHECK에 의해 차단되는 문제 수정
--
-- 기존: USING + WITH CHECK 모두 "5개 필드 전부 NOT NULL이면 차단"
--   → 마지막 필드를 채우는 순간 WITH CHECK(업데이트 후 행 기준)에 걸려 저장 불가
--
-- 수정: WITH CHECK를 true로 변경
--   → USING만으로 "이미 완료된 건의 재수정"을 차단
--   → 미완료 → 완료로 전환하는 업데이트는 허용

DROP POLICY IF EXISTS "inspections_update" ON public.asset_inspections;
CREATE POLICY "inspections_update" ON public.asset_inspections
  FOR UPDATE TO authenticated
  USING (
    public.is_admin()
    OR NOT (
      inspection_building IS NOT NULL
      AND inspection_floor IS NOT NULL
      AND inspection_position IS NOT NULL
      AND inspection_photo IS NOT NULL
      AND signature_image IS NOT NULL
    )
  )
  WITH CHECK (true);

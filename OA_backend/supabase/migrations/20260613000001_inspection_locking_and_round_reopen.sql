-- =============================================================================
-- 실사 잠금(N차 등록) + 라운드 재오픈 RPC
--
-- 1) asset_inspections에 locked boolean 추가 (등록 후 잠금)
-- 2) RLS 갱신: locked=true는 admin만 수정/해제 가능
-- 3) reopen_inspection_round RPC (관리자만, closed→active)
-- =============================================================================

-- 1) locked 컬럼
ALTER TABLE public.asset_inspections
  ADD COLUMN IF NOT EXISTS locked boolean NOT NULL DEFAULT false;

CREATE INDEX IF NOT EXISTS idx_inspections_locked
  ON public.asset_inspections(locked) WHERE locked = true;

-- 2) UPDATE RLS 갱신:
--    locked=true → admin만 변경 가능
--    locked=false → 기존 정책(완성된 행은 admin만, 미완성은 누구나)
DROP POLICY IF EXISTS inspections_update ON public.asset_inspections;

CREATE POLICY inspections_update ON public.asset_inspections
  FOR UPDATE TO authenticated
  USING (
    -- 잠긴 행은 admin만 수정/잠금해제 가능
    (NOT locked OR public.is_admin())
    AND (
      public.is_admin()
      OR (NOT (
        inspection_building IS NOT NULL
        AND inspection_floor IS NOT NULL
        AND inspection_position IS NOT NULL
        AND inspection_photo IS NOT NULL
        AND signature_image IS NOT NULL
      ))
    )
  )
  WITH CHECK (true);

-- 3) 라운드 재오픈 RPC (관리자만, closed → active 복귀)
CREATE OR REPLACE FUNCTION public.reopen_inspection_round(p_round_id bigint)
RETURNS public.inspection_rounds
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
AS $$
DECLARE
  v_row public.inspection_rounds;
BEGIN
  IF NOT public.is_admin() THEN
    RAISE EXCEPTION '권한 없음: 관리자만 라운드 재오픈 가능합니다';
  END IF;

  -- 이미 active 라운드가 있으면 거부 (동시 1개 active 규칙 유지)
  IF EXISTS (
    SELECT 1 FROM public.inspection_rounds
    WHERE status = 'active' AND id <> p_round_id
  ) THEN
    RAISE EXCEPTION '이미 진행 중인 라운드가 있습니다. 먼저 종료해주세요.';
  END IF;

  UPDATE public.inspection_rounds
  SET status = 'active',
      closed_at = NULL,
      closed_by = NULL,
      updated_at = now()
  WHERE id = p_round_id
  RETURNING * INTO v_row;

  IF v_row.id IS NULL THEN
    RAISE EXCEPTION '라운드를 찾을 수 없음: %', p_round_id;
  END IF;

  RETURN v_row;
END;
$$;

GRANT EXECUTE ON FUNCTION public.reopen_inspection_round(bigint) TO authenticated;

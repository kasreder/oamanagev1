-- =============================================================================
-- 자산별 실사 회차 표시 (assets.inspection_round_no)
--
-- - 기본값 0
-- - 라운드 종료(close) 시 그 라운드 inspection의 자산들 = round 번호로 갱신
-- - 라운드 재오픈(reopen) 시 그 자산들 = round - 1로 환원
-- - 모든 기존 자산 0으로 초기화
-- =============================================================================

-- 1) 컬럼 추가
ALTER TABLE public.assets
  ADD COLUMN IF NOT EXISTS inspection_round_no integer NOT NULL DEFAULT 0;

CREATE INDEX IF NOT EXISTS idx_assets_inspection_round_no
  ON public.assets(inspection_round_no);

-- 2) 모든 자산 0으로 초기화 (요청에 따른 일괄 리셋)
UPDATE public.assets SET inspection_round_no = 0
WHERE inspection_round_no IS DISTINCT FROM 0;

-- 3) close_inspection_round RPC 갱신:
--    종료 시 그 라운드의 inspection 자산들 inspection_round_no = round
CREATE OR REPLACE FUNCTION public.close_inspection_round(p_round_id bigint)
RETURNS public.inspection_rounds
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
AS $$
DECLARE
  v_row public.inspection_rounds;
  v_user_id bigint;
BEGIN
  IF NOT public.is_admin_group() THEN
    RAISE EXCEPTION 'forbidden: admin group only';
  END IF;

  SELECT id INTO v_user_id FROM public.users WHERE auth_uid = auth.uid();

  UPDATE public.inspection_rounds
  SET status = 'closed',
      closed_at = now(),
      closed_by = v_user_id,
      updated_at = now()
  WHERE id = p_round_id AND status = 'active'
  RETURNING * INTO v_row;

  IF v_row.id IS NULL THEN
    RAISE EXCEPTION '활성 상태의 라운드를 찾을 수 없음: %', p_round_id;
  END IF;

  -- 이 라운드에 속한 inspection들의 자산 → round 번호로 갱신
  UPDATE public.assets a
  SET inspection_round_no = v_row.round
  FROM public.asset_inspections ai
  WHERE ai.round_id = v_row.id
    AND ai.asset_id = a.id;

  RETURN v_row;
END;
$$;

-- 4) reopen_inspection_round RPC 갱신:
--    재오픈 시 그 라운드의 자산들 inspection_round_no = round - 1
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

  -- 이 라운드에 속한 inspection들의 자산 → round - 1로 환원
  -- (음수 방지: GREATEST 0)
  UPDATE public.assets a
  SET inspection_round_no = GREATEST(v_row.round - 1, 0)
  FROM public.asset_inspections ai
  WHERE ai.round_id = v_row.id
    AND ai.asset_id = a.id;

  RETURN v_row;
END;
$$;

GRANT EXECUTE ON FUNCTION public.close_inspection_round(bigint) TO authenticated;
GRANT EXECUTE ON FUNCTION public.reopen_inspection_round(bigint) TO authenticated;

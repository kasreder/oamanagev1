-- =============================================================================
-- 라운드 시작 시 모든 자산에 대해 inspection 자동 생성
--
-- start_inspection_round를 갱신:
--   1) 라운드 상태 active로 전환
--   2) 모든 자산.inspection_round_no = round
--   3) 이 라운드에 아직 inspection이 없는 자산들에 대해 inspection 일괄 생성 (locked=false)
-- =============================================================================

CREATE OR REPLACE FUNCTION public.start_inspection_round(p_round_id bigint)
RETURNS public.inspection_rounds
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
AS $$
DECLARE
  v_row public.inspection_rounds;
  v_user_id bigint;
  v_inserted integer;
BEGIN
  IF NOT public.is_admin_group() THEN
    RAISE EXCEPTION 'forbidden: admin group only';
  END IF;

  IF EXISTS (SELECT 1 FROM public.inspection_rounds WHERE status = 'active') THEN
    RAISE EXCEPTION 'already_active: 이미 진행 중인 실사가 있습니다. 먼저 종료해주세요.';
  END IF;

  SELECT id INTO v_user_id FROM public.users WHERE auth_uid = auth.uid();

  UPDATE public.inspection_rounds
  SET status = 'active',
      started_by = v_user_id,
      started_at = now(),
      updated_at = now()
  WHERE id = p_round_id AND status = 'draft'
  RETURNING * INTO v_row;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'not_found: 라운드를 찾을 수 없거나 이미 시작된 상태입니다.';
  END IF;

  -- 모든 자산의 회차 표시 갱신
  UPDATE public.assets
  SET inspection_round_no = v_row.round
  WHERE inspection_round_no IS DISTINCT FROM v_row.round;

  -- 이 라운드에 아직 inspection이 없는 자산에 대해 일괄 생성
  WITH ins AS (
    INSERT INTO public.asset_inspections (
      asset_id, asset_code, asset_type, round_id, locked, synced
    )
    SELECT a.id, a.asset_uid, a.category, v_row.id, false, true
    FROM public.assets a
    WHERE NOT EXISTS (
      SELECT 1 FROM public.asset_inspections ai
      WHERE ai.asset_id = a.id AND ai.round_id = v_row.id
    )
    RETURNING 1
  )
  SELECT count(*) INTO v_inserted FROM ins;

  RAISE NOTICE 'auto-created % inspections for round %', v_inserted, v_row.id;
  RETURN v_row;
END;
$$;

GRANT EXECUTE ON FUNCTION public.start_inspection_round(bigint) TO authenticated;

-- =============================================================================
-- 자산의 inspection_round_no가 활성 라운드의 round 번호를 그대로 따라가도록 변경.
--
-- - start_inspection_round: 모든 자산.inspection_round_no = round
-- - close_inspection_round: 자산 변경 없음 (라운드 표시 유지)
-- - reopen_inspection_round: 모든 자산.inspection_round_no = round - 1
-- =============================================================================

-- 1) start_inspection_round 갱신
CREATE OR REPLACE FUNCTION public.start_inspection_round(p_round_id bigint)
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

  -- 모든 자산 inspection_round_no를 이 라운드의 round 번호로 일괄 갱신
  UPDATE public.assets
  SET inspection_round_no = v_row.round
  WHERE inspection_round_no IS DISTINCT FROM v_row.round;

  RETURN v_row;
END;
$$;

-- 2) close_inspection_round 갱신 (자산 변경 X — 표시 그대로 유지)
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

  RETURN v_row;
END;
$$;

-- 3) reopen_inspection_round 갱신: 모든 자산을 round - 1로 (0 최소)
CREATE OR REPLACE FUNCTION public.reopen_inspection_round(p_round_id bigint)
RETURNS public.inspection_rounds
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
AS $$
DECLARE
  v_row public.inspection_rounds;
  v_prev integer;
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

  -- 모든 자산을 (round - 1)로 환원, 음수 방지
  v_prev := GREATEST(v_row.round - 1, 0);
  UPDATE public.assets
  SET inspection_round_no = v_prev
  WHERE inspection_round_no IS DISTINCT FROM v_prev;

  RETURN v_row;
END;
$$;

GRANT EXECUTE ON FUNCTION public.start_inspection_round(bigint) TO authenticated;
GRANT EXECUTE ON FUNCTION public.close_inspection_round(bigint) TO authenticated;
GRANT EXECUTE ON FUNCTION public.reopen_inspection_round(bigint) TO authenticated;

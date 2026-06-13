-- =============================================================================
-- delete_inspection_round RPC
-- - 관리자만
-- - active 상태는 거부 (먼저 종료해야 함)
-- - 종속된 inspection이 있으면 거부 (옵션: force=true면 inspection.round_id NULL 처리 후 삭제)
-- =============================================================================

CREATE OR REPLACE FUNCTION public.delete_inspection_round(
  p_round_id bigint,
  p_force    boolean DEFAULT false
)
RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
AS $$
DECLARE
  v_row public.inspection_rounds;
  v_count integer;
BEGIN
  IF NOT public.is_admin() THEN
    RAISE EXCEPTION '권한 없음: 관리자만 라운드 삭제 가능합니다';
  END IF;

  SELECT * INTO v_row FROM public.inspection_rounds WHERE id = p_round_id;
  IF v_row.id IS NULL THEN
    RAISE EXCEPTION '라운드를 찾을 수 없음: %', p_round_id;
  END IF;

  IF v_row.status = 'active' THEN
    RAISE EXCEPTION '진행 중인 라운드는 삭제할 수 없습니다. 먼저 종료하세요.';
  END IF;

  SELECT count(*) INTO v_count
  FROM public.asset_inspections WHERE round_id = p_round_id;

  IF v_count > 0 AND NOT p_force THEN
    RAISE EXCEPTION
      '이 라운드에 속한 실사가 %건 있습니다. 먼저 정리하거나 force=true로 호출하세요.',
      v_count;
  END IF;

  IF v_count > 0 AND p_force THEN
    UPDATE public.asset_inspections SET round_id = NULL WHERE round_id = p_round_id;
  END IF;

  DELETE FROM public.inspection_rounds WHERE id = p_round_id;

  RETURN jsonb_build_object(
    'deleted_round_id',   p_round_id,
    'year',               v_row.year,
    'round',              v_row.round,
    'forced',             p_force,
    'detached_inspections', CASE WHEN p_force THEN v_count ELSE 0 END
  );
END;
$$;

GRANT EXECUTE ON FUNCTION public.delete_inspection_round(bigint, boolean) TO authenticated;

-- =============================================================================
-- verify_user RPC: assets.user_employee_id 기반 비교로 변경
--
-- 기존 문제: users 테이블에서 employee_name으로 employee_id를 찾는 우회 경로.
--   → users에 등록 안 된 단말 사용자(외부직원 등)는 NULL 반환 → boolean 에러.
--
-- 변경: 자산 상세에 입력된 user_name + user_employee_id와 단말 입력값을 직접 비교.
--   COALESCE로 NULL 안전 처리 (옛 자산의 user_employee_id가 NULL일 경우 false 처리).
-- =============================================================================

CREATE OR REPLACE FUNCTION public.verify_user(
  p_asset_uid   text,
  p_user_name   text,
  p_employee_id text
)
RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER
AS $$
DECLARE
  v_db_user_name   text;
  v_db_employee_id text;
  v_matched        boolean;
BEGIN
  SELECT user_name, user_employee_id
  INTO v_db_user_name, v_db_employee_id
  FROM public.assets
  WHERE asset_uid = p_asset_uid;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'asset not found: %', p_asset_uid;
  END IF;

  -- NULL = NULL은 NULL이므로 COALESCE로 false 처리
  v_matched := COALESCE(
    v_db_user_name = p_user_name AND v_db_employee_id = p_employee_id,
    false
  );

  UPDATE public.assets
  SET
    last_verified_at    = now(),
    verification_status = CASE WHEN v_matched THEN 'verified' ELSE 'mismatch' END
  WHERE asset_uid = p_asset_uid;

  RETURN jsonb_build_object(
    'matched',     v_matched,
    'message',     CASE WHEN v_matched
                        THEN '사용자 확인 완료'
                        ELSE '기존 사용자와 다른 사용자입니다. OA관리부서에 문의하세요.'
                   END,
    'verified_at', now()
  );
END;
$$;

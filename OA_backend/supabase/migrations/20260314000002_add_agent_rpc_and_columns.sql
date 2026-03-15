-- =============================================================================
-- assets 테이블 에이전트 관련 컬럼 추가 + RPC 함수
-- =============================================================================

-- assets 테이블 컬럼 추가
ALTER TABLE public.assets
  ADD COLUMN IF NOT EXISTS last_verified_at       timestamptz,
  ADD COLUMN IF NOT EXISTS verification_status    text,
  ADD COLUMN IF NOT EXISTS assignment_status       text,
  ADD COLUMN IF NOT EXISTS assignment_confirmed_at timestamptz;

-- 9.6 update_heartbeat RPC
CREATE OR REPLACE FUNCTION public.update_heartbeat(
  p_asset_uid text,
  p_system_info jsonb DEFAULT NULL
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  UPDATE public.assets
  SET
    last_active_at = now(),
    specifications = CASE
      WHEN p_system_info IS NOT NULL
      THEN jsonb_set(COALESCE(specifications, '{}'), '{device_status}', p_system_info)
      ELSE specifications
    END
  WHERE asset_uid = p_asset_uid;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'asset not found: %', p_asset_uid;
  END IF;
END;
$$;

REVOKE ALL ON FUNCTION public.update_heartbeat(text, jsonb) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.update_heartbeat(text, jsonb) TO authenticated;

-- 9.7 verify_user RPC
CREATE OR REPLACE FUNCTION public.verify_user(
  p_asset_uid text,
  p_user_name text,
  p_employee_id text
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_db_user_name text;
  v_db_employee_id text;
  v_matched boolean;
BEGIN
  SELECT user_name INTO v_db_user_name
  FROM public.assets
  WHERE asset_uid = p_asset_uid;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'asset not found: %', p_asset_uid;
  END IF;

  SELECT employee_id INTO v_db_employee_id
  FROM public.users
  WHERE employee_name = v_db_user_name;

  v_matched := (v_db_user_name = p_user_name AND v_db_employee_id = p_employee_id);

  UPDATE public.assets
  SET
    last_verified_at = now(),
    verification_status = CASE WHEN v_matched THEN 'verified' ELSE 'mismatch' END
  WHERE asset_uid = p_asset_uid;

  RETURN jsonb_build_object(
    'matched', v_matched,
    'message', CASE
      WHEN v_matched THEN '사용자 확인 완료'
      ELSE '기존 사용자와 다른 사용자입니다. OA관리부서에 문의하세요.'
    END,
    'verified_at', now()
  );
END;
$$;

REVOKE ALL ON FUNCTION public.verify_user(text, text, text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.verify_user(text, text, text) TO authenticated;

-- 9.8 confirm_assignment RPC
CREATE OR REPLACE FUNCTION public.confirm_assignment(
  p_asset_uid text,
  p_user_name text
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_db_user_name text;
  v_assignment_status text;
BEGIN
  SELECT user_name, assignment_status
  INTO v_db_user_name, v_assignment_status
  FROM public.assets
  WHERE asset_uid = p_asset_uid;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'asset not found: %', p_asset_uid;
  END IF;

  IF v_assignment_status != 'pending' THEN
    RETURN jsonb_build_object(
      'success', false,
      'message', '수령 대기 중인 배정이 없습니다.'
    );
  END IF;

  IF v_db_user_name != p_user_name THEN
    RETURN jsonb_build_object(
      'success', false,
      'message', '배정된 사용자 이름과 일치하지 않습니다.'
    );
  END IF;

  UPDATE public.assets
  SET
    assignment_status = 'confirmed',
    assignment_confirmed_at = now()
  WHERE asset_uid = p_asset_uid;

  RETURN jsonb_build_object(
    'success', true,
    'message', '자산 수령이 확인되었습니다.',
    'confirmed_at', now()
  );
END;
$$;

REVOKE ALL ON FUNCTION public.confirm_assignment(text, text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.confirm_assignment(text, text) TO authenticated;

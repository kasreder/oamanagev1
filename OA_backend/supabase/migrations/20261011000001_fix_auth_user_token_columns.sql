-- =============================================================================
-- auth.users 토큰 컬럼 NULL로 인한 로그인 500 수정
--
-- 증상: POST /auth/v1/token → 500 "Database error querying schema"
--       (Scan error on column "confirmation_token": converting NULL to string)
-- 원인: admin_create_user_secure 가 auth.users 에 직접 INSERT 하면서 기본값이 없는
--       confirmation_token / recovery_token / email_change_token_new / email_change
--       를 비워 둠 → GoTrue 가 NULL 을 문자열로 읽지 못해 해당 계정은 로그인 불가.
-- 조치: 1) 기존 NULL 행을 빈 문자열로 보정 (이미 만들어진 계정 복구)
--       2) 함수가 이후 생성하는 계정은 빈 문자열로 INSERT
-- 권한/검증 로직은 변경하지 않음 (CREATE OR REPLACE 는 기존 GRANT 를 유지).
-- =============================================================================

BEGIN;

UPDATE auth.users
SET confirmation_token     = COALESCE(confirmation_token, ''),
    recovery_token         = COALESCE(recovery_token, ''),
    email_change_token_new = COALESCE(email_change_token_new, ''),
    email_change           = COALESCE(email_change, '')
WHERE confirmation_token IS NULL
   OR recovery_token IS NULL
   OR email_change_token_new IS NULL
   OR email_change IS NULL;

CREATE OR REPLACE FUNCTION public.admin_create_user_secure(p_employee_id text, p_employee_name text, p_role text DEFAULT 'user'::text, p_org_dept text DEFAULT NULL::text, p_email text DEFAULT NULL::text, p_password text DEFAULT NULL::text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'pg_catalog', 'public', 'auth', 'extensions', 'pg_temp'
AS $function$
DECLARE
  v_auth_uid uuid := gen_random_uuid();
  v_email text;
  v_password text;
  v_typed boolean := p_password IS NOT NULL AND length(btrim(p_password)) > 0;
  v_id bigint;
BEGIN
  IF NOT public.is_admin() THEN
    RAISE EXCEPTION 'permission denied: admin only';
  END IF;
  IF p_role = 'admin' AND NOT public.is_master_admin() THEN
    RAISE EXCEPTION 'only master admin can create an admin account';
  END IF;
  IF p_employee_id IS NULL OR length(btrim(p_employee_id)) = 0 THEN
    RAISE EXCEPTION 'employee_id is required';
  END IF;
  IF p_employee_name IS NULL OR length(btrim(p_employee_name)) = 0 THEN
    RAISE EXCEPTION 'employee_name is required';
  END IF;
  IF p_role NOT IN ('user', 'admin', 'operator1', 'operator2') THEN
    RAISE EXCEPTION 'invalid role: %', p_role;
  END IF;
  IF v_typed AND length(btrim(p_password)) < 8 THEN
    RAISE EXCEPTION 'password must be at least 8 characters';
  END IF;
  IF EXISTS (SELECT 1 FROM public.users WHERE employee_id = p_employee_id) THEN
    RAISE EXCEPTION 'employee_id % already exists', p_employee_id;
  END IF;

  v_email := COALESCE(p_email, p_employee_id || '@oamanager.internal');
  v_password := CASE WHEN v_typed THEN btrim(p_password)
                     ELSE 'OA-' || encode(extensions.gen_random_bytes(12), 'hex') END;

  INSERT INTO auth.users (
    id, instance_id, aud, role, email, encrypted_password, email_confirmed_at,
    raw_app_meta_data, raw_user_meta_data, created_at, updated_at,
    confirmation_token, recovery_token, email_change_token_new, email_change
  ) VALUES (
    v_auth_uid, '00000000-0000-0000-0000-000000000000',
    'authenticated', 'authenticated', v_email,
    extensions.crypt(v_password, extensions.gen_salt('bf')), now(),
    jsonb_build_object('provider', 'email', 'providers', jsonb_build_array('email')),
    jsonb_build_object(
      'employee_id', p_employee_id,
      'employee_name', p_employee_name,
      'organization_dept', p_org_dept,
      'auth_provider', 'email'
    ),
    now(), now(),
    '', '', '', ''
  );

  INSERT INTO auth.identities (
    id, user_id, provider_id, identity_data, provider,
    last_sign_in_at, created_at, updated_at
  ) VALUES (
    v_auth_uid, v_auth_uid, v_email,
    jsonb_build_object('sub', v_auth_uid::text, 'email', v_email, 'email_verified', true),
    'email', now(), now(), now()
  ) ON CONFLICT (provider_id, provider) DO NOTHING;

  -- handle_new_user() 트리거가 프로필 생성. 이후 role/부서/강제변경 플래그만 갱신.
  UPDATE public.users
  SET role = p_role,
      organization_dept = p_org_dept,
      must_change_password = true
  WHERE auth_uid = v_auth_uid
  RETURNING id INTO v_id;

  IF v_id IS NULL THEN
    RAISE EXCEPTION 'profile provisioning failed for %', p_employee_id;
  END IF;

  RETURN jsonb_build_object(
    'user_id', v_id,
    'employee_id', p_employee_id,
    'temporary_password', CASE WHEN v_typed THEN NULL ELSE v_password END
  );
END;
$function$;

COMMIT;

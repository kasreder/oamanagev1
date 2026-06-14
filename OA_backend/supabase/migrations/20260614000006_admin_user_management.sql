-- =============================================================================
-- 관리자용 유저 관리 RPC
--
-- - admin_reset_user_password(p_employee_id) — 비번 = employee_id||'1234!'
-- - admin_create_user(p_employee_id, p_employee_name, p_role, p_org_dept,
--     p_email default null) — 신규 유저 생성 (비번 = employee_id||'1234!')
--
-- 모두 호출자가 is_admin_group()일 때만 동작 (마스터관리자/관리자 모두 포함).
-- =============================================================================

BEGIN;

CREATE OR REPLACE FUNCTION public.admin_reset_user_password(
  p_employee_id text
) RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, auth, extensions
AS $$
DECLARE
  v_auth_uid uuid;
  v_new_pw   text;
BEGIN
  IF NOT public.is_admin_group() THEN
    RAISE EXCEPTION 'permission denied: admin only';
  END IF;

  SELECT auth_uid INTO v_auth_uid
  FROM public.users WHERE employee_id = p_employee_id;
  IF v_auth_uid IS NULL THEN
    RAISE EXCEPTION 'user % has no auth_uid (cannot reset)', p_employee_id;
  END IF;

  v_new_pw := p_employee_id || '1234!';

  UPDATE auth.users
  SET encrypted_password = extensions.crypt(v_new_pw, extensions.gen_salt('bf')),
      updated_at = now()
  WHERE id = v_auth_uid;
END;
$$;

CREATE OR REPLACE FUNCTION public.admin_create_user(
  p_employee_id    text,
  p_employee_name  text,
  p_role           text DEFAULT 'user',
  p_org_dept       text DEFAULT NULL,
  p_email          text DEFAULT NULL
) RETURNS bigint
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, auth, extensions
AS $$
DECLARE
  v_auth_uid uuid;
  v_email    text;
  v_pw       text;
  v_id       bigint;
BEGIN
  IF NOT public.is_admin_group() THEN
    RAISE EXCEPTION 'permission denied: admin only';
  END IF;

  IF p_employee_id IS NULL OR length(btrim(p_employee_id)) = 0 THEN
    RAISE EXCEPTION 'employee_id is required';
  END IF;
  IF p_role NOT IN ('user','admin','operator1','operator2') THEN
    RAISE EXCEPTION 'invalid role: %', p_role;
  END IF;
  IF EXISTS (SELECT 1 FROM public.users WHERE employee_id = p_employee_id) THEN
    RAISE EXCEPTION 'employee_id % already exists', p_employee_id;
  END IF;

  v_email := COALESCE(p_email, p_employee_id || '@oa.local');
  v_pw    := p_employee_id || '1234!';

  -- auth.users 행 생성
  v_auth_uid := gen_random_uuid();
  INSERT INTO auth.users (
    id, instance_id, aud, role, email,
    encrypted_password, email_confirmed_at,
    raw_app_meta_data, raw_user_meta_data,
    created_at, updated_at
  ) VALUES (
    v_auth_uid, '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated',
    v_email,
    extensions.crypt(v_pw, extensions.gen_salt('bf')),
    now(),
    jsonb_build_object('provider', 'email', 'providers', jsonb_build_array('email')),
    jsonb_build_object('employee_id', p_employee_id, 'employee_name', p_employee_name),
    now(), now()
  );

  -- public.users 행 생성
  INSERT INTO public.users (
    auth_uid, employee_id, employee_name, role, organization_dept
  ) VALUES (
    v_auth_uid, p_employee_id, p_employee_name, p_role, p_org_dept
  ) RETURNING id INTO v_id;

  RETURN v_id;
END;
$$;

GRANT EXECUTE ON FUNCTION public.admin_reset_user_password(text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.admin_create_user(text, text, text, text, text) TO authenticated;

COMMIT;

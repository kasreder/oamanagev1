-- 1) 설정 › 유저정보: 사번(employee_id)까지 수정 — 로그인 이메일/identity 동기 갱신
-- 2) 인수증 삭제: 관리자(role=admin)만

BEGIN;

DROP FUNCTION IF EXISTS public.admin_update_user_profile(text, text, text);

CREATE OR REPLACE FUNCTION public.admin_update_user_profile(
  p_employee_id     text,
  p_employee_name   text,
  p_org_dept        text DEFAULT NULL,
  p_new_employee_id text DEFAULT NULL
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'pg_catalog', 'public', 'auth', 'pg_temp'
AS $$
DECLARE
  v_role text;
  v_is_master boolean;
  v_auth_uid uuid;
  v_new_id text := NULLIF(btrim(COALESCE(p_new_employee_id, '')), '');
  v_old_email text;
  v_new_email text;
BEGIN
  IF NOT public.is_admin() THEN
    RAISE EXCEPTION 'permission denied: admin only';
  END IF;
  IF p_employee_name IS NULL OR length(btrim(p_employee_name)) = 0 THEN
    RAISE EXCEPTION 'employee_name is required';
  END IF;

  SELECT role, is_master_admin, auth_uid INTO v_role, v_is_master, v_auth_uid
  FROM public.users WHERE employee_id = p_employee_id FOR UPDATE;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'user not found: %', p_employee_id;
  END IF;
  IF (v_role = 'admin' OR v_is_master) AND NOT public.is_master_admin() THEN
    RAISE EXCEPTION 'only master admin can edit an admin account';
  END IF;

  IF v_new_id IS NOT NULL AND v_new_id <> p_employee_id THEN
    IF v_auth_uid = auth.uid() THEN
      RAISE EXCEPTION 'cannot change your own employee_id while logged in';
    END IF;
    IF v_new_id !~ '^[A-Za-z0-9._-]+$' THEN
      RAISE EXCEPTION 'invalid employee_id: %', v_new_id;
    END IF;
    IF EXISTS (SELECT 1 FROM public.users WHERE employee_id = v_new_id) THEN
      RAISE EXCEPTION 'employee_id % already exists', v_new_id;
    END IF;

    -- 로그인 이메일은 {사번}@oamanager.internal 규칙 → auth 쪽도 함께 갱신
    IF v_auth_uid IS NOT NULL THEN
      SELECT email INTO v_old_email FROM auth.users WHERE id = v_auth_uid;
      v_new_email := v_new_id || '@oamanager.internal';
      IF EXISTS (SELECT 1 FROM auth.users WHERE email = v_new_email AND id <> v_auth_uid) THEN
        RAISE EXCEPTION 'login email % already in use', v_new_email;
      END IF;

      UPDATE auth.users
      SET email = v_new_email,
          raw_user_meta_data = COALESCE(raw_user_meta_data, '{}'::jsonb)
                               || jsonb_build_object('employee_id', v_new_id),
          updated_at = now()
      WHERE id = v_auth_uid;

      UPDATE auth.identities
      SET provider_id = v_new_email,
          identity_data = COALESCE(identity_data, '{}'::jsonb)
                          || jsonb_build_object('email', v_new_email),
          updated_at = now()
      WHERE user_id = v_auth_uid AND provider = 'email';
    END IF;

    UPDATE public.users SET employee_id = v_new_id WHERE employee_id = p_employee_id;
    p_employee_id := v_new_id;
  END IF;

  UPDATE public.users
  SET employee_name = btrim(p_employee_name),
      organization_dept = NULLIF(btrim(COALESCE(p_org_dept, '')), '')
  WHERE employee_id = p_employee_id;
END;
$$;

GRANT EXECUTE ON FUNCTION public.admin_update_user_profile(text,text,text,text) TO authenticated;

-- 인수증 삭제는 관리자만 (항목은 FK CASCADE)
DROP POLICY IF EXISTS receipts_delete ON public.receipts;
CREATE POLICY receipts_delete ON public.receipts
  FOR DELETE TO authenticated USING (public.is_admin());

COMMIT;

-- 설정 › 유저정보: 관리자가 사용자 이름/부서 수정 (admin 계정은 마스터만)
CREATE OR REPLACE FUNCTION public.admin_update_user_profile(
  p_employee_id   text,
  p_employee_name text,
  p_org_dept      text DEFAULT NULL
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'pg_catalog', 'public', 'pg_temp'
AS $$
DECLARE
  v_role text;
  v_is_master boolean;
BEGIN
  IF NOT public.is_admin() THEN
    RAISE EXCEPTION 'permission denied: admin only';
  END IF;
  IF p_employee_name IS NULL OR length(btrim(p_employee_name)) = 0 THEN
    RAISE EXCEPTION 'employee_name is required';
  END IF;

  SELECT role, is_master_admin INTO v_role, v_is_master
  FROM public.users WHERE employee_id = p_employee_id FOR UPDATE;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'user not found: %', p_employee_id;
  END IF;
  IF (v_role = 'admin' OR v_is_master) AND NOT public.is_master_admin() THEN
    RAISE EXCEPTION 'only master admin can edit an admin account';
  END IF;

  UPDATE public.users
  SET employee_name = btrim(p_employee_name),
      organization_dept = NULLIF(btrim(COALESCE(p_org_dept, '')), '')
  WHERE employee_id = p_employee_id;
END;
$$;

GRANT EXECUTE ON FUNCTION public.admin_update_user_profile(text,text,text) TO authenticated;

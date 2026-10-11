-- =============================================================================
-- 관리자용 유저 관리 RPC
--
-- Legacy compatibility stubs.  They must never generate deterministic
-- credentials; the later *_secure RPCs are the only supported account paths.
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
BEGIN
  RAISE EXCEPTION 'legacy password reset RPC is disabled; use admin_reset_user_password_secure';
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
BEGIN
  RAISE EXCEPTION 'legacy user creation RPC is disabled; use admin_create_user_secure';
END;
$$;

GRANT EXECUTE ON FUNCTION public.admin_reset_user_password(text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.admin_create_user(text, text, text, text, text) TO authenticated;

COMMIT;

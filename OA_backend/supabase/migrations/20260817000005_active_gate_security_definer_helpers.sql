-- =============================================================================
-- OA Manager: a banned/deleted account must not regain privileges through
-- SECURITY DEFINER helper functions, which bypass the restrictive table RLS
-- containment policy.
-- =============================================================================

BEGIN;

CREATE OR REPLACE FUNCTION public.current_user_id()
RETURNS bigint
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = pg_catalog, public, auth, pg_temp
AS $$
  SELECT u.id
  FROM public.users AS u
  JOIN auth.users AS au ON au.id = u.auth_uid
  WHERE au.id = auth.uid()
    AND au.deleted_at IS NULL
    AND (au.banned_until IS NULL OR au.banned_until <= now())
  LIMIT 1;
$$;

CREATE OR REPLACE FUNCTION public.is_admin()
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = pg_catalog, public, auth, pg_temp
AS $$
  SELECT public.is_current_auth_account_active()
    AND EXISTS (
      SELECT 1
      FROM public.users AS u
      WHERE u.auth_uid = auth.uid()
        AND u.role = 'admin'
    );
$$;

CREATE OR REPLACE FUNCTION public.is_admin_group()
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = pg_catalog, public, auth, pg_temp
AS $$
  SELECT public.is_current_auth_account_active()
    AND EXISTS (
      SELECT 1
      FROM public.users AS u
      WHERE u.auth_uid = auth.uid()
        AND u.role IN ('admin', 'operator1', 'operator2')
    );
$$;

CREATE OR REPLACE FUNCTION public.is_master_admin()
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = pg_catalog, public, auth, pg_temp
AS $$
  SELECT public.is_current_auth_account_active()
    AND EXISTS (
      SELECT 1
      FROM public.users AS u
      WHERE u.auth_uid = auth.uid()
        AND u.role = 'admin'
        AND u.is_master_admin = true
    );
$$;

CREATE OR REPLACE FUNCTION public.is_current_asset_assignee(p_asset_uid text)
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = pg_catalog, public, auth, pg_temp
AS $$
  SELECT public.is_current_auth_account_active()
    AND EXISTS (
      SELECT 1
      FROM public.assets AS a
      JOIN public.users AS u ON u.id = a.user_id
      WHERE a.asset_uid = p_asset_uid
        AND u.auth_uid = auth.uid()
    );
$$;

CREATE OR REPLACE FUNCTION public.is_inspection_participant(p_inspection_id bigint)
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = pg_catalog, public, auth, pg_temp
AS $$
  SELECT public.is_current_auth_account_active()
    AND EXISTS (
      SELECT 1
      FROM public.asset_inspections AS ai
      LEFT JOIN public.assets AS a ON a.id = ai.asset_id
      JOIN public.users AS u
        ON u.id = ai.user_id OR u.id = a.user_id
      WHERE ai.id = p_inspection_id
        AND u.auth_uid = auth.uid()
    );
$$;

CREATE OR REPLACE FUNCTION public.is_legacy_agent()
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = pg_catalog, public, auth, pg_temp
AS $$
  SELECT public.is_current_auth_account_active()
    AND EXISTS (
      SELECT 1
      FROM public.users AS u
      WHERE u.auth_uid = auth.uid()
        AND lower(u.employee_id) = 'agent'
    );
$$;

REVOKE ALL ON FUNCTION public.current_user_id()
  FROM PUBLIC, anon, authenticated, service_role;
REVOKE ALL ON FUNCTION public.is_admin()
  FROM PUBLIC, anon, authenticated, service_role;
REVOKE ALL ON FUNCTION public.is_admin_group()
  FROM PUBLIC, anon, authenticated, service_role;
REVOKE ALL ON FUNCTION public.is_master_admin()
  FROM PUBLIC, anon, authenticated, service_role;
REVOKE ALL ON FUNCTION public.is_current_asset_assignee(text)
  FROM PUBLIC, anon, authenticated, service_role;
REVOKE ALL ON FUNCTION public.is_inspection_participant(bigint)
  FROM PUBLIC, anon, authenticated, service_role;
REVOKE ALL ON FUNCTION public.is_legacy_agent()
  FROM PUBLIC, anon, authenticated, service_role;

GRANT EXECUTE ON FUNCTION public.current_user_id()
  TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.is_admin()
  TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.is_admin_group()
  TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.is_master_admin()
  TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.is_current_asset_assignee(text)
  TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.is_inspection_participant(bigint)
  TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.is_legacy_agent()
  TO authenticated, service_role;

COMMIT;

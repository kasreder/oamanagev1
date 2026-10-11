-- =============================================================================
-- OA Manager: emergency containment for compromised seeded accounts and broad
-- data reads. Apply only after creating a separately held break-glass master.
-- =============================================================================

BEGIN;

-- A GoTrue ban is not consulted by an already-issued JWT at PostgreSQL.  This
-- restrictive policy predicate closes that gap for every database request made
-- with an authenticated role, including Storage and private Realtime later on.
CREATE OR REPLACE FUNCTION public.is_current_auth_account_active()
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = pg_catalog, public, auth, pg_temp
AS $$
  SELECT EXISTS (
    SELECT 1
    FROM public.users AS u
    JOIN auth.users AS au ON au.id = u.auth_uid
    WHERE au.id = auth.uid()
      AND au.deleted_at IS NULL
      AND (au.banned_until IS NULL OR au.banned_until <= now())
  );
$$;

REVOKE ALL ON FUNCTION public.is_current_auth_account_active()
  FROM PUBLIC, anon, authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.is_current_auth_account_active()
  TO authenticated, service_role;

-- This is deliberately a restrictive policy, so it ANDs with every current
-- and future permissive policy instead of replacing the application policy.
DO $$
DECLARE
  r record;
BEGIN
  FOR r IN
    SELECT * FROM (VALUES
      ('public'::text, 'users'::text),
      ('public', 'assets'),
      ('public', 'asset_inspections'),
      ('public', 'drawings'),
      ('public', 'device_tokens'),
      ('public', 'notifications'),
      ('public', 'access_settings'),
      ('public', 'agent_settings'),
      ('public', 'dropdown_options'),
      ('public', 'inspection_rounds'),
      ('storage', 'objects'),
      ('storage', 'buckets')
    ) AS targets(schema_name, table_name)
  LOOP
    EXECUTE format(
      'DROP POLICY IF EXISTS auth_banned_account_block ON %I.%I',
      r.schema_name, r.table_name
    );
    EXECUTE format(
      'CREATE POLICY auth_banned_account_block ON %I.%I AS RESTRICTIVE FOR ALL TO authenticated USING (public.is_current_auth_account_active()) WITH CHECK (public.is_current_auth_account_active())',
      r.schema_name, r.table_name
    );
  END LOOP;
END;
$$;

DROP POLICY IF EXISTS auth_banned_account_block ON realtime.messages;
CREATE POLICY auth_banned_account_block ON realtime.messages
  AS RESTRICTIVE FOR ALL TO authenticated
  USING (public.is_current_auth_account_active())
  WITH CHECK (public.is_current_auth_account_active());

-- Contain the known seeded identities.  Their existing sessions are removed,
-- their passwords are replaced with inaccessible random values, and the auth
-- ban is enforced immediately by the restrictive policies above.  The seed
-- source is removed separately so a future reset cannot recreate this state.
WITH affected AS (
  SELECT au.id
  FROM auth.users AS au
  JOIN public.users AS u ON u.auth_uid = au.id
  WHERE lower(u.employee_id) IN (
    'temp01', 'admin01', 'oper01', 'oper02',
    'user01', 'user02', 'user03', 'user04', 'user05'
  )
), removed_sessions AS (
  DELETE FROM auth.sessions AS s
  USING affected AS a
  WHERE s.user_id = a.id
)
UPDATE auth.users AS au
SET banned_until = 'infinity'::timestamptz,
    encrypted_password = extensions.crypt(
      encode(extensions.gen_random_bytes(32), 'hex'),
      extensions.gen_salt('bf')
    ),
    recovery_token = encode(extensions.gen_random_bytes(32), 'hex'),
    reauthentication_token = encode(extensions.gen_random_bytes(32), 'hex'),
    updated_at = now()
FROM affected AS a
WHERE au.id = a.id;

-- Do not leave the old default master as a dormant master account once the
-- separately provisioned incident break-glass master exists.
UPDATE public.users
SET is_master_admin = false
WHERE lower(employee_id) IN ('temp01', 'admin01', 'oper01', 'oper02')
  AND is_master_admin = true
  AND EXISTS (
    SELECT 1
    FROM public.users AS recovery
    WHERE recovery.employee_id LIKE 'incident-breakglass-%'
      AND recovery.role = 'admin'
      AND recovery.is_master_admin = true
  );

-- Until ownership assignments are completed and 00001 is rolled out with its
-- private Realtime/client release, regular accounts must not read the global
-- asset, inspection, drawing, or attachment inventories.
DROP POLICY IF EXISTS assets_select_authenticated ON public.assets;
CREATE POLICY assets_select_authenticated ON public.assets
  FOR SELECT TO authenticated
  USING (public.is_admin_group());

DROP POLICY IF EXISTS drawings_select_authenticated ON public.drawings;
CREATE POLICY drawings_select_authenticated ON public.drawings
  FOR SELECT TO authenticated
  USING (public.is_admin_group());

DROP POLICY IF EXISTS inspections_select_authenticated ON public.asset_inspections;
CREATE POLICY inspections_select_authenticated ON public.asset_inspections
  FOR SELECT TO authenticated
  USING (public.is_admin_group());

DROP POLICY IF EXISTS inspection_photos_select_authenticated ON storage.objects;
CREATE POLICY inspection_photos_select_authenticated ON storage.objects
  FOR SELECT TO authenticated
  USING (bucket_id = 'inspection-photos' AND public.is_admin_group());

DROP POLICY IF EXISTS inspection_signatures_select_authenticated ON storage.objects;
CREATE POLICY inspection_signatures_select_authenticated ON storage.objects
  FOR SELECT TO authenticated
  USING (bucket_id = 'inspection-signatures' AND public.is_admin_group());

DROP POLICY IF EXISTS drawing_images_select_authenticated ON storage.objects;
CREATE POLICY drawing_images_select_authenticated ON storage.objects
  FOR SELECT TO authenticated
  USING (bucket_id = 'drawing-images' AND public.is_admin_group());

-- Limit the direct object-upload blast radius while the assignment-aware
-- upload-ticket flow is prepared.  Existing objects are not modified.
UPDATE storage.buckets
SET file_size_limit = 10485760,
    allowed_mime_types = ARRAY['image/jpeg', 'image/png']::text[]
WHERE id = 'inspection-photos';

UPDATE storage.buckets
SET file_size_limit = 10485760,
    allowed_mime_types = ARRAY['image/png']::text[]
WHERE id = 'inspection-signatures';

UPDATE storage.buckets
SET file_size_limit = 10485760,
    allowed_mime_types = ARRAY['image/jpeg', 'image/png', 'image/webp']::text[]
WHERE id = 'drawing-images';

COMMIT;

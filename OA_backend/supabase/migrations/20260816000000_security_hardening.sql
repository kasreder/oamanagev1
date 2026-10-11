-- =============================================================================
-- OA Manager: anonymous exposure removal and least-privilege hardening
--
-- This migration is intentionally idempotent.  It is safe to apply after the
-- emergency anonymous-access containment transaction: it replaces the original
-- policy names and atomically refreshes the restrictive legacy_agent_block
-- emergency policy with the durable employee_id predicate.
-- =============================================================================

BEGIN;

-- -----------------------------------------------------------------------------
-- 1. Privilege helpers.  These functions bypass RLS only to resolve the caller's
--    own role/profile; every table reference is schema-qualified.
-- -----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.current_user_id()
RETURNS bigint
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = pg_catalog, public, auth
AS $$
  SELECT u.id
  FROM public.users AS u
  WHERE u.auth_uid = auth.uid()
  LIMIT 1;
$$;

CREATE OR REPLACE FUNCTION public.is_admin()
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = pg_catalog, public, auth
AS $$
  SELECT EXISTS (
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
SET search_path = pg_catalog, public, auth
AS $$
  SELECT EXISTS (
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
SET search_path = pg_catalog, public, auth
AS $$
  SELECT EXISTS (
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
SET search_path = pg_catalog, public, auth
AS $$
  SELECT EXISTS (
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
SET search_path = pg_catalog, public, auth
AS $$
  SELECT EXISTS (
    SELECT 1
    FROM public.asset_inspections AS ai
    LEFT JOIN public.assets AS a ON a.id = ai.asset_id
    JOIN public.users AS u
      ON u.id = ai.user_id OR u.id = a.user_id
    WHERE ai.id = p_inspection_id
      AND u.auth_uid = auth.uid()
  );
$$;

-- The legacy agent login was embedded in every APK.  Its employee_id is the
-- stable identifier; never key this containment to one copied UUID or email.
CREATE OR REPLACE FUNCTION public.is_legacy_agent()
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = pg_catalog, public, auth
AS $$
  SELECT EXISTS (
    SELECT 1
    FROM public.users AS u
    WHERE u.auth_uid = auth.uid()
      AND lower(u.employee_id) = 'agent'
  );
$$;

-- Never leave SECURITY DEFINER helpers executable through PUBLIC/anon.
REVOKE ALL ON FUNCTION public.current_user_id() FROM PUBLIC;
REVOKE ALL ON FUNCTION public.is_admin() FROM PUBLIC;
REVOKE ALL ON FUNCTION public.is_admin_group() FROM PUBLIC;
REVOKE ALL ON FUNCTION public.is_master_admin() FROM PUBLIC;
REVOKE ALL ON FUNCTION public.is_current_asset_assignee(text) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.is_inspection_participant(bigint) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.is_legacy_agent() FROM PUBLIC;

-- -----------------------------------------------------------------------------
-- 2. Explicitly remove anonymous schema/table access.  RLS is retained as the
--    data boundary; grants make accidental future anon policies non-effective.
-- -----------------------------------------------------------------------------
REVOKE USAGE ON SCHEMA public FROM PUBLIC;
REVOKE USAGE ON SCHEMA public FROM anon;
REVOKE CREATE ON SCHEMA public FROM PUBLIC, anon, authenticated;
REVOKE ALL PRIVILEGES ON ALL TABLES IN SCHEMA public FROM PUBLIC;
REVOKE ALL PRIVILEGES ON ALL TABLES IN SCHEMA public FROM anon;
REVOKE ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA public FROM PUBLIC;
REVOKE ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA public FROM anon;
GRANT USAGE ON SCHEMA public TO authenticated, service_role;
GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA public TO authenticated;
GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA public TO service_role;

-- Re-grant only the authenticated application surface.  RLS below remains the
-- row-level authority; these SQL grants merely allow PostgREST to reach it.
GRANT SELECT ON TABLE public.users TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE public.assets TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE public.asset_inspections TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE public.drawings TO authenticated;
GRANT SELECT, INSERT, UPDATE ON TABLE public.device_tokens TO authenticated;
GRANT SELECT, INSERT, UPDATE ON TABLE public.notifications TO authenticated;
GRANT SELECT, UPDATE ON TABLE public.access_settings TO authenticated;
GRANT SELECT, UPDATE ON TABLE public.agent_settings TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE public.dropdown_options TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE public.inspection_rounds TO authenticated;
GRANT SELECT ON TABLE public.asset_inspections_with_asset TO authenticated;
GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA public TO service_role;

REVOKE USAGE ON SCHEMA storage FROM PUBLIC;
REVOKE USAGE ON SCHEMA storage FROM anon;
REVOKE CREATE ON SCHEMA storage FROM PUBLIC, anon, authenticated;
REVOKE ALL PRIVILEGES ON ALL TABLES IN SCHEMA storage FROM PUBLIC;
REVOKE ALL PRIVILEGES ON ALL TABLES IN SCHEMA storage FROM anon;
REVOKE ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA storage FROM PUBLIC;
REVOKE ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA storage FROM anon;
GRANT USAGE ON SCHEMA storage TO authenticated, service_role;
GRANT SELECT ON TABLE storage.buckets TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE storage.objects TO authenticated;
GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA storage TO authenticated;
GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA storage TO service_role;
GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA storage TO service_role;

-- -----------------------------------------------------------------------------
-- 3. public.users.  A regular account may read its own profile only.  Account
--    role/master changes are RPC-only below, so a client cannot self-promote.
-- -----------------------------------------------------------------------------
DROP POLICY IF EXISTS users_select ON public.users;
DROP POLICY IF EXISTS users_select_authenticated ON public.users;
DROP POLICY IF EXISTS users_select_own_or_admin_group ON public.users;
DROP POLICY IF EXISTS users_update_own ON public.users;
DROP POLICY IF EXISTS users_update_admin_group ON public.users;

CREATE POLICY users_select_own_or_admin_group ON public.users
  FOR SELECT TO authenticated
  USING (auth_uid = auth.uid() OR public.is_admin_group());

REVOKE INSERT, UPDATE, DELETE ON public.users FROM authenticated;
GRANT SELECT ON public.users TO authenticated;

-- -----------------------------------------------------------------------------
-- 4. Assets and drawings.  All signed-in OA staff retain read access.  Master
--    data mutation is limited to the existing administrator group.
-- -----------------------------------------------------------------------------
DROP POLICY IF EXISTS assets_select ON public.assets;
DROP POLICY IF EXISTS assets_select_authenticated ON public.assets;
DROP POLICY IF EXISTS assets_insert ON public.assets;
DROP POLICY IF EXISTS assets_update ON public.assets;
DROP POLICY IF EXISTS assets_delete ON public.assets;
DROP POLICY IF EXISTS assets_insert_admin_group ON public.assets;
DROP POLICY IF EXISTS assets_update_admin_group ON public.assets;
DROP POLICY IF EXISTS assets_delete_admin_group ON public.assets;

CREATE POLICY assets_select_authenticated ON public.assets
  FOR SELECT TO authenticated USING (true);
CREATE POLICY assets_insert_admin_group ON public.assets
  FOR INSERT TO authenticated WITH CHECK (public.is_admin_group());
CREATE POLICY assets_update_admin_group ON public.assets
  FOR UPDATE TO authenticated
  USING (public.is_admin_group())
  WITH CHECK (public.is_admin_group());
CREATE POLICY assets_delete_admin_group ON public.assets
  FOR DELETE TO authenticated
  USING (
    public.is_admin_group()
    AND NOT EXISTS (
      SELECT 1 FROM public.asset_inspections AS ai
      WHERE ai.asset_id = assets.id
    )
  );

DROP POLICY IF EXISTS drawings_select ON public.drawings;
DROP POLICY IF EXISTS drawings_select_authenticated ON public.drawings;
DROP POLICY IF EXISTS drawings_insert ON public.drawings;
DROP POLICY IF EXISTS drawings_update ON public.drawings;
DROP POLICY IF EXISTS drawings_delete ON public.drawings;
DROP POLICY IF EXISTS drawings_insert_admin_group ON public.drawings;
DROP POLICY IF EXISTS drawings_update_admin_group ON public.drawings;
DROP POLICY IF EXISTS drawings_delete_admin_group ON public.drawings;

CREATE POLICY drawings_select_authenticated ON public.drawings
  FOR SELECT TO authenticated USING (true);
CREATE POLICY drawings_insert_admin_group ON public.drawings
  FOR INSERT TO authenticated WITH CHECK (public.is_admin_group());
CREATE POLICY drawings_update_admin_group ON public.drawings
  FOR UPDATE TO authenticated
  USING (public.is_admin_group())
  WITH CHECK (public.is_admin_group());
CREATE POLICY drawings_delete_admin_group ON public.drawings
  FOR DELETE TO authenticated USING (public.is_admin_group());

-- -----------------------------------------------------------------------------
-- 5. Inspection ownership.  Inspection rounds create their records through the
--    controlled round RPC; direct creation is administrator-group only.  A
--    non-admin can claim an unclaimed inspection only during its active round.
--    Once claimed, it cannot be edited by another account; locked/completed
--    rows remain admin-only, as the UI promises.
-- -----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.claim_inspection_owner()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, public, auth
AS $$
DECLARE
  v_user_id bigint;
  v_auth_uid text;
BEGIN
  IF public.is_admin() THEN
    RETURN NEW;
  END IF;

  v_user_id := public.current_user_id();
  v_auth_uid := auth.uid()::text;
  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'forbidden: user profile is required';
  END IF;

  IF OLD.user_id IS NOT NULL AND OLD.user_id <> v_user_id THEN
    RAISE EXCEPTION 'forbidden: inspection is owned by another user';
  END IF;

  IF NEW.user_id IS NOT NULL
     AND NEW.user_id <> COALESCE(OLD.user_id, v_user_id) THEN
    RAISE EXCEPTION 'forbidden: inspection owner cannot be reassigned';
  END IF;

  -- The round and source asset are system-controlled when a round begins.
  -- A regular inspector may edit inspection observations, but cannot move a
  -- claimed row to a different asset/round or alter the administrator lock.
  IF NEW.asset_id IS DISTINCT FROM OLD.asset_id
     OR NEW.round_id IS DISTINCT FROM OLD.round_id
     OR NEW.locked IS DISTINCT FROM OLD.locked
     OR NEW.inspection_count IS DISTINCT FROM OLD.inspection_count THEN
    RAISE EXCEPTION 'forbidden: inspection assignment fields are immutable';
  END IF;

  -- New files are written beneath the caller UUID.  Keeping this invariant in
  -- the row as well as storage RLS prevents a user from attaching/deleting a
  -- different employee's object path.
  IF NEW.inspection_photo IS DISTINCT FROM OLD.inspection_photo
     AND NEW.inspection_photo IS NOT NULL
     AND split_part(NEW.inspection_photo, '/', 1) <> v_auth_uid THEN
    RAISE EXCEPTION 'forbidden: inspection photo must be owned by the caller';
  END IF;
  IF NEW.signature_image IS DISTINCT FROM OLD.signature_image
     AND NEW.signature_image IS NOT NULL
     AND split_part(NEW.signature_image, '/', 1) <> v_auth_uid THEN
    RAISE EXCEPTION 'forbidden: inspection signature must be owned by the caller';
  END IF;

  NEW.user_id := COALESCE(OLD.user_id, v_user_id);
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_claim_inspection_owner ON public.asset_inspections;
CREATE TRIGGER trg_claim_inspection_owner
  BEFORE UPDATE ON public.asset_inspections
  FOR EACH ROW EXECUTE FUNCTION public.claim_inspection_owner();

DROP POLICY IF EXISTS inspections_select ON public.asset_inspections;
DROP POLICY IF EXISTS inspections_select_authenticated ON public.asset_inspections;
DROP POLICY IF EXISTS inspections_insert ON public.asset_inspections;
DROP POLICY IF EXISTS inspections_update ON public.asset_inspections;
DROP POLICY IF EXISTS inspections_delete ON public.asset_inspections;
DROP POLICY IF EXISTS inspections_insert_active_round ON public.asset_inspections;
DROP POLICY IF EXISTS inspections_update_claimed_active ON public.asset_inspections;
DROP POLICY IF EXISTS inspections_delete_admin ON public.asset_inspections;

CREATE POLICY inspections_select_authenticated ON public.asset_inspections
  FOR SELECT TO authenticated USING (true);

CREATE POLICY inspections_insert_active_round ON public.asset_inspections
  FOR INSERT TO authenticated
  WITH CHECK (public.is_admin_group());

CREATE POLICY inspections_update_claimed_active ON public.asset_inspections
  FOR UPDATE TO authenticated
  USING (
    public.is_admin()
    OR (
      locked = false
      AND (user_id IS NULL OR user_id = public.current_user_id())
      AND NOT (
        inspection_building IS NOT NULL
        AND inspection_floor IS NOT NULL
        AND inspection_position IS NOT NULL
        AND inspection_photo IS NOT NULL
        AND signature_image IS NOT NULL
      )
      AND EXISTS (
        SELECT 1 FROM public.inspection_rounds AS r
        WHERE r.id = asset_inspections.round_id
          AND r.status = 'active'
      )
    )
  )
  WITH CHECK (
    public.is_admin()
    OR (
      user_id = public.current_user_id()
      AND EXISTS (
        SELECT 1 FROM public.inspection_rounds AS r
        WHERE r.id = asset_inspections.round_id
          AND r.status = 'active'
      )
    )
  );

CREATE POLICY inspections_delete_admin ON public.asset_inspections
  FOR DELETE TO authenticated USING (public.is_admin());

-- -----------------------------------------------------------------------------
-- 6. Agent and system tables.
-- -----------------------------------------------------------------------------
DROP POLICY IF EXISTS device_tokens_select ON public.device_tokens;
DROP POLICY IF EXISTS device_tokens_insert ON public.device_tokens;
DROP POLICY IF EXISTS device_tokens_update ON public.device_tokens;
DROP POLICY IF EXISTS device_tokens_delete ON public.device_tokens;
DROP POLICY IF EXISTS device_tokens_select_admin_group ON public.device_tokens;
DROP POLICY IF EXISTS device_tokens_insert_assignee ON public.device_tokens;
DROP POLICY IF EXISTS device_tokens_update_assignee ON public.device_tokens;
DROP POLICY IF EXISTS device_tokens_delete_assignee ON public.device_tokens;

CREATE POLICY device_tokens_select_admin_group ON public.device_tokens
  FOR SELECT TO authenticated USING (public.is_admin_group());
CREATE POLICY device_tokens_insert_assignee ON public.device_tokens
  FOR INSERT TO authenticated
  WITH CHECK (
    public.is_admin_group()
    OR public.is_current_asset_assignee(asset_uid)
  );
CREATE POLICY device_tokens_update_assignee ON public.device_tokens
  FOR UPDATE TO authenticated
  USING (
    public.is_admin_group()
    OR public.is_current_asset_assignee(asset_uid)
  )
  WITH CHECK (
    public.is_admin_group()
    OR public.is_current_asset_assignee(asset_uid)
  );
CREATE POLICY device_tokens_delete_assignee ON public.device_tokens
  FOR DELETE TO authenticated
  USING (
    public.is_admin_group()
    OR public.is_current_asset_assignee(asset_uid)
  );

DROP POLICY IF EXISTS notifications_select ON public.notifications;
DROP POLICY IF EXISTS notifications_insert ON public.notifications;
DROP POLICY IF EXISTS notifications_update ON public.notifications;
DROP POLICY IF EXISTS notifications_select_admin_group ON public.notifications;
DROP POLICY IF EXISTS notifications_insert_admin_group ON public.notifications;
DROP POLICY IF EXISTS notifications_update_admin_group ON public.notifications;

CREATE POLICY notifications_select_admin_group ON public.notifications
  FOR SELECT TO authenticated USING (public.is_admin_group());
CREATE POLICY notifications_insert_admin_group ON public.notifications
  FOR INSERT TO authenticated WITH CHECK (public.is_admin_group());
CREATE POLICY notifications_update_admin_group ON public.notifications
  FOR UPDATE TO authenticated
  USING (public.is_admin_group())
  WITH CHECK (public.is_admin_group());

DROP POLICY IF EXISTS access_settings_select ON public.access_settings;
DROP POLICY IF EXISTS access_settings_select_authenticated ON public.access_settings;
DROP POLICY IF EXISTS access_settings_update ON public.access_settings;
DROP POLICY IF EXISTS access_settings_update_admin ON public.access_settings;
CREATE POLICY access_settings_select_authenticated ON public.access_settings
  FOR SELECT TO authenticated USING (true);
CREATE POLICY access_settings_update_admin ON public.access_settings
  FOR UPDATE TO authenticated
  USING (public.is_admin())
  WITH CHECK (public.is_admin());

DROP POLICY IF EXISTS agent_settings_select ON public.agent_settings;
DROP POLICY IF EXISTS agent_settings_select_authenticated ON public.agent_settings;
DROP POLICY IF EXISTS agent_settings_update ON public.agent_settings;
DROP POLICY IF EXISTS agent_settings_update_admin ON public.agent_settings;
CREATE POLICY agent_settings_select_authenticated ON public.agent_settings
  FOR SELECT TO authenticated USING (true);
CREATE POLICY agent_settings_update_admin ON public.agent_settings
  FOR UPDATE TO authenticated
  USING (public.is_admin())
  WITH CHECK (public.is_admin());

-- -----------------------------------------------------------------------------
-- 7. Storage.  Existing private files remain readable by signed-in OA users,
--    while anonymous object access is removed.  Drawing uploads are admin-group
--    only because only that group can modify drawing metadata.
-- -----------------------------------------------------------------------------
DROP POLICY IF EXISTS inspection_photos_select ON storage.objects;
DROP POLICY IF EXISTS inspection_photos_select_authenticated ON storage.objects;
DROP POLICY IF EXISTS inspection_photos_insert ON storage.objects;
DROP POLICY IF EXISTS inspection_photos_update ON storage.objects;
DROP POLICY IF EXISTS inspection_photos_delete ON storage.objects;
DROP POLICY IF EXISTS inspection_photos_insert_owner ON storage.objects;
DROP POLICY IF EXISTS inspection_photos_update_owner ON storage.objects;
DROP POLICY IF EXISTS inspection_photos_delete_owner_or_admin ON storage.objects;
CREATE POLICY inspection_photos_select_authenticated ON storage.objects
  FOR SELECT TO authenticated USING (bucket_id = 'inspection-photos');
CREATE POLICY inspection_photos_insert_owner ON storage.objects
  FOR INSERT TO authenticated
  WITH CHECK (
    bucket_id = 'inspection-photos'
    AND (storage.foldername(name))[1] = auth.uid()::text
  );
CREATE POLICY inspection_photos_update_owner ON storage.objects
  FOR UPDATE TO authenticated
  USING (
    bucket_id = 'inspection-photos'
    AND (storage.foldername(name))[1] = auth.uid()::text
  )
  WITH CHECK (
    bucket_id = 'inspection-photos'
    AND (storage.foldername(name))[1] = auth.uid()::text
  );
CREATE POLICY inspection_photos_delete_owner_or_admin ON storage.objects
  FOR DELETE TO authenticated
  USING (
    bucket_id = 'inspection-photos'
    AND (
      public.is_admin()
      OR (storage.foldername(name))[1] = auth.uid()::text
      OR EXISTS (
        SELECT 1
        FROM public.asset_inspections AS ai
        WHERE ai.inspection_photo = storage.objects.name
          AND ai.user_id = public.current_user_id()
      )
    )
  );

DROP POLICY IF EXISTS inspection_signatures_select ON storage.objects;
DROP POLICY IF EXISTS inspection_signatures_select_authenticated ON storage.objects;
DROP POLICY IF EXISTS inspection_signatures_insert ON storage.objects;
DROP POLICY IF EXISTS inspection_signatures_update ON storage.objects;
DROP POLICY IF EXISTS inspection_signatures_delete ON storage.objects;
DROP POLICY IF EXISTS inspection_signatures_insert_owner ON storage.objects;
DROP POLICY IF EXISTS inspection_signatures_update_owner ON storage.objects;
DROP POLICY IF EXISTS inspection_signatures_delete_owner_or_admin ON storage.objects;
CREATE POLICY inspection_signatures_select_authenticated ON storage.objects
  FOR SELECT TO authenticated USING (bucket_id = 'inspection-signatures');
CREATE POLICY inspection_signatures_insert_owner ON storage.objects
  FOR INSERT TO authenticated
  WITH CHECK (
    bucket_id = 'inspection-signatures'
    AND (storage.foldername(name))[1] = auth.uid()::text
  );
CREATE POLICY inspection_signatures_update_owner ON storage.objects
  FOR UPDATE TO authenticated
  USING (
    bucket_id = 'inspection-signatures'
    AND (storage.foldername(name))[1] = auth.uid()::text
  )
  WITH CHECK (
    bucket_id = 'inspection-signatures'
    AND (storage.foldername(name))[1] = auth.uid()::text
  );
CREATE POLICY inspection_signatures_delete_owner_or_admin ON storage.objects
  FOR DELETE TO authenticated
  USING (
    bucket_id = 'inspection-signatures'
    AND (
      public.is_admin()
      OR (storage.foldername(name))[1] = auth.uid()::text
      OR EXISTS (
        SELECT 1
        FROM public.asset_inspections AS ai
        WHERE ai.signature_image = storage.objects.name
          AND ai.user_id = public.current_user_id()
      )
    )
  );

DROP POLICY IF EXISTS drawing_images_select ON storage.objects;
DROP POLICY IF EXISTS drawing_images_select_authenticated ON storage.objects;
DROP POLICY IF EXISTS drawing_images_insert ON storage.objects;
DROP POLICY IF EXISTS drawing_images_update ON storage.objects;
DROP POLICY IF EXISTS drawing_images_delete ON storage.objects;
DROP POLICY IF EXISTS drawing_images_insert_admin_group ON storage.objects;
DROP POLICY IF EXISTS drawing_images_update_admin_group ON storage.objects;
DROP POLICY IF EXISTS drawing_images_delete_admin_group ON storage.objects;
CREATE POLICY drawing_images_select_authenticated ON storage.objects
  FOR SELECT TO authenticated USING (bucket_id = 'drawing-images');
CREATE POLICY drawing_images_insert_admin_group ON storage.objects
  FOR INSERT TO authenticated
  WITH CHECK (bucket_id = 'drawing-images' AND public.is_admin_group());
CREATE POLICY drawing_images_update_admin_group ON storage.objects
  FOR UPDATE TO authenticated
  USING (bucket_id = 'drawing-images' AND public.is_admin_group())
  WITH CHECK (bucket_id = 'drawing-images' AND public.is_admin_group());
CREATE POLICY drawing_images_delete_admin_group ON storage.objects
  FOR DELETE TO authenticated
  USING (bucket_id = 'drawing-images' AND public.is_admin_group());

-- -----------------------------------------------------------------------------
-- 7.5 Legacy APK containment.  Refresh the live emergency block atomically so
--     an old copied UUID predicate cannot survive the deployment.  The
--     restrictive policy ANDs with every ordinary RLS policy and blocks the
--     generic employee_id='agent' JWT from reading or writing OA data.
-- -----------------------------------------------------------------------------
DO $$
DECLARE
  v_table text;
BEGIN
  FOREACH v_table IN ARRAY ARRAY[
    'users',
    'assets',
    'asset_inspections',
    'drawings',
    'device_tokens',
    'notifications',
    'access_settings',
    'agent_settings',
    'dropdown_options',
    'inspection_rounds'
  ]
  LOOP
    EXECUTE format('DROP POLICY IF EXISTS legacy_agent_block ON public.%I', v_table);
    EXECUTE format(
      'CREATE POLICY legacy_agent_block ON public.%I AS RESTRICTIVE FOR ALL TO authenticated USING (NOT public.is_legacy_agent()) WITH CHECK (NOT public.is_legacy_agent())',
      v_table
    );
  END LOOP;

  FOREACH v_table IN ARRAY ARRAY['objects', 'buckets']
  LOOP
    EXECUTE format('DROP POLICY IF EXISTS legacy_agent_block ON storage.%I', v_table);
    EXECUTE format(
      'CREATE POLICY legacy_agent_block ON storage.%I AS RESTRICTIVE FOR ALL TO authenticated USING (NOT public.is_legacy_agent()) WITH CHECK (NOT public.is_legacy_agent())',
      v_table
    );
  END LOOP;
END;
$$;

-- Banning the identity blocks new sign-ins; the restrictive RLS policy above
-- also contains any already-issued access JWT until it expires.  The predicate
-- intentionally matches employee_id instead of a hard-coded UUID/email.
UPDATE auth.users AS au
SET banned_until = 'infinity'::timestamptz,
    encrypted_password = extensions.crypt(
      encode(extensions.gen_random_bytes(32), 'hex'),
      extensions.gen_salt('bf')
    ),
    updated_at = now()
WHERE EXISTS (
  SELECT 1
  FROM public.users AS u
  WHERE u.auth_uid = au.id
    AND lower(u.employee_id) = 'agent'
);

DELETE FROM auth.sessions AS s
USING public.users AS u
WHERE s.user_id = u.auth_uid
  AND lower(u.employee_id) = 'agent';

-- -----------------------------------------------------------------------------
-- 8. RPC guard repairs.  SECURITY DEFINER is retained only where it is needed,
--    with caller authorization inside every externally callable function.
--
-- Legacy OA agents share one APK-embedded user credential.  That identity must
-- never be permitted to act for arbitrary assets, so its heartbeat/verification
-- RPCs remain ungranted until per-device enrollment is deployed.  Do not restore
-- these grants for the shared account; see the deployment runbook for phase two.
-- -----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.get_expiring_assets()
RETURNS TABLE (
  id bigint,
  asset_uid text,
  name text,
  supply_type text,
  supply_end_date timestamptz,
  d_day int
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, public, auth
AS $$
BEGIN
  IF NOT public.is_admin_group() THEN
    RAISE EXCEPTION 'forbidden: admin group only';
  END IF;

  RETURN QUERY
  SELECT a.id, a.asset_uid, a.name, a.supply_type, a.supply_end_date,
         (a.supply_end_date::date - CURRENT_DATE)::int
  FROM public.assets AS a
  WHERE a.supply_type IN ('렌탈', '대여')
    AND a.supply_end_date IS NOT NULL
    AND a.supply_end_date <= CURRENT_DATE + INTERVAL '7 days'
    AND a.supply_end_date >= CURRENT_DATE
  ORDER BY a.supply_end_date ASC;
END;
$$;

CREATE OR REPLACE FUNCTION public.update_heartbeat(
  p_asset_uid text,
  p_system_info jsonb DEFAULT NULL
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, public, auth
AS $$
DECLARE
  v_mac text;
BEGIN
  IF NOT (
    public.is_admin_group()
    OR public.is_current_asset_assignee(p_asset_uid)
  ) THEN
    RAISE EXCEPTION 'forbidden: asset assignee or administrator required';
  END IF;

  v_mac := NULLIF(btrim(p_system_info->>'mac_address'), '');
  UPDATE public.assets
  SET last_active_at = now(),
      specifications = CASE
        WHEN p_system_info IS NOT NULL
        THEN jsonb_set(COALESCE(specifications, '{}'::jsonb), '{device_status}', p_system_info)
        ELSE specifications
      END,
      mac_address = COALESCE(v_mac, mac_address)
  WHERE asset_uid = p_asset_uid;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'asset not found: %', p_asset_uid;
  END IF;
END;
$$;

CREATE OR REPLACE FUNCTION public.verify_user(
  p_asset_uid text,
  p_user_name text,
  p_employee_id text
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, public, auth
AS $$
DECLARE
  v_db_user_name text;
  v_db_employee_id text;
  v_matched boolean;
BEGIN
  IF NOT (
    public.is_admin_group()
    OR public.is_current_asset_assignee(p_asset_uid)
  ) THEN
    RAISE EXCEPTION 'forbidden: asset assignee or administrator required';
  END IF;

  SELECT user_name, user_employee_id
  INTO v_db_user_name, v_db_employee_id
  FROM public.assets
  WHERE asset_uid = p_asset_uid;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'asset not found: %', p_asset_uid;
  END IF;

  v_matched := COALESCE(
    v_db_user_name = p_user_name AND v_db_employee_id = p_employee_id,
    false
  );

  UPDATE public.assets
  SET last_verified_at = now(),
      verification_status = CASE WHEN v_matched THEN 'verified' ELSE 'mismatch' END
  WHERE asset_uid = p_asset_uid;

  RETURN jsonb_build_object(
    'matched', v_matched,
    'message', CASE WHEN v_matched
      THEN '사용자 확인 완료'
      ELSE '기존 사용자와 다른 사용자입니다. OA관리부서에 문의하세요.'
    END,
    'verified_at', now()
  );
END;
$$;

CREATE OR REPLACE FUNCTION public.confirm_assignment(
  p_asset_uid text,
  p_user_name text
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, public, auth
AS $$
DECLARE
  v_db_user_name text;
  v_assignment_status text;
BEGIN
  IF NOT (
    public.is_admin_group()
    OR public.is_current_asset_assignee(p_asset_uid)
  ) THEN
    RAISE EXCEPTION 'forbidden: asset assignee or administrator required';
  END IF;

  SELECT user_name, assignment_status
  INTO v_db_user_name, v_assignment_status
  FROM public.assets
  WHERE asset_uid = p_asset_uid;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'asset not found: %', p_asset_uid;
  END IF;
  IF v_assignment_status <> 'pending' THEN
    RETURN jsonb_build_object('success', false, 'message', '수령 대기 중인 배정이 없습니다.');
  END IF;
  IF v_db_user_name IS DISTINCT FROM p_user_name THEN
    RETURN jsonb_build_object('success', false, 'message', '배정된 사용자 이름과 일치하지 않습니다.');
  END IF;

  UPDATE public.assets
  SET assignment_status = 'confirmed', assignment_confirmed_at = now()
  WHERE asset_uid = p_asset_uid;

  RETURN jsonb_build_object('success', true, 'message', '자산 수령이 확인되었습니다.', 'confirmed_at', now());
END;
$$;

CREATE OR REPLACE FUNCTION public.request_inspection_recheck(p_inspection_id bigint)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, public, auth
AS $$
DECLARE
  v_asset_uid text;
BEGIN
  IF NOT (
    public.is_admin_group()
    OR public.is_inspection_participant(p_inspection_id)
  ) THEN
    RAISE EXCEPTION 'forbidden: inspection participant or administrator required';
  END IF;

  SELECT COALESCE(a.asset_uid, ai.asset_code, ai.id::text)
  INTO v_asset_uid
  FROM public.asset_inspections AS ai
  LEFT JOIN public.assets AS a ON a.id = ai.asset_id
  WHERE ai.id = p_inspection_id;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'inspection % not found', p_inspection_id;
  END IF;

  INSERT INTO public.notifications (asset_uid, type, title, body)
  VALUES (
    v_asset_uid,
    'recheck_request',
    format('재실사 요청: %s', v_asset_uid),
    format('실사 ID %s에 대한 재실사가 요청되었습니다.', p_inspection_id)
  );
END;
$$;

-- Account lifecycle is master-admin-only.  Direct table UPDATE is intentionally
-- removed above, and generated temporary passwords eliminate the predictable
-- employee-id-derived credential pattern.
CREATE OR REPLACE FUNCTION public.admin_reset_user_password_secure(p_employee_id text)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, public, auth, extensions
AS $$
DECLARE
  v_auth_uid uuid;
  v_password text;
BEGIN
  IF NOT public.is_master_admin() THEN
    RAISE EXCEPTION 'permission denied: master admin only';
  END IF;

  SELECT auth_uid INTO v_auth_uid
  FROM public.users WHERE employee_id = p_employee_id;
  IF v_auth_uid IS NULL THEN
    RAISE EXCEPTION 'user % has no auth account', p_employee_id;
  END IF;

  v_password := 'OA-' || encode(extensions.gen_random_bytes(12), 'hex');
  UPDATE auth.users
  SET encrypted_password = extensions.crypt(v_password, extensions.gen_salt('bf')),
      updated_at = now()
  WHERE id = v_auth_uid;

  RETURN jsonb_build_object('employee_id', p_employee_id, 'temporary_password', v_password);
END;
$$;

CREATE OR REPLACE FUNCTION public.admin_create_user_secure(
  p_employee_id text,
  p_employee_name text,
  p_role text DEFAULT 'user',
  p_org_dept text DEFAULT NULL,
  p_email text DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, public, auth, extensions
AS $$
DECLARE
  v_auth_uid uuid := gen_random_uuid();
  v_email text;
  v_password text;
  v_id bigint;
BEGIN
  IF NOT public.is_master_admin() THEN
    RAISE EXCEPTION 'permission denied: master admin only';
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
  IF EXISTS (SELECT 1 FROM public.users WHERE employee_id = p_employee_id) THEN
    RAISE EXCEPTION 'employee_id % already exists', p_employee_id;
  END IF;

  v_email := COALESCE(p_email, p_employee_id || '@oamanager.internal');
  v_password := 'OA-' || encode(extensions.gen_random_bytes(12), 'hex');

  INSERT INTO auth.users (
    id, instance_id, aud, role, email, encrypted_password, email_confirmed_at,
    raw_app_meta_data, raw_user_meta_data, created_at, updated_at
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
    now(), now()
  );

  INSERT INTO auth.identities (
    id, user_id, provider_id, identity_data, provider,
    last_sign_in_at, created_at, updated_at
  ) VALUES (
    v_auth_uid, v_auth_uid, v_email,
    jsonb_build_object('sub', v_auth_uid::text, 'email', v_email, 'email_verified', true),
    'email', now(), now(), now()
  ) ON CONFLICT (provider_id, provider) DO NOTHING;

  -- handle_new_user() creates the profile.  Update its application role only
  -- after the auth row has been created successfully.
  UPDATE public.users
  SET role = p_role,
      organization_dept = p_org_dept
  WHERE auth_uid = v_auth_uid
  RETURNING id INTO v_id;

  IF v_id IS NULL THEN
    RAISE EXCEPTION 'profile provisioning failed for %', p_employee_id;
  END IF;

  RETURN jsonb_build_object(
    'user_id', v_id,
    'employee_id', p_employee_id,
    'temporary_password', v_password
  );
END;
$$;

CREATE OR REPLACE FUNCTION public.admin_update_user_role(
  p_employee_id text,
  p_role text
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, public, auth
AS $$
DECLARE
  v_is_master boolean;
BEGIN
  IF NOT public.is_master_admin() THEN
    RAISE EXCEPTION 'permission denied: master admin only';
  END IF;
  IF p_role NOT IN ('user', 'admin', 'operator1', 'operator2') THEN
    RAISE EXCEPTION 'invalid role: %', p_role;
  END IF;

  SELECT is_master_admin INTO v_is_master
  FROM public.users WHERE employee_id = p_employee_id FOR UPDATE;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'user not found: %', p_employee_id;
  END IF;
  IF v_is_master AND p_role <> 'admin'
     AND (SELECT count(*) FROM public.users WHERE is_master_admin) <= 1 THEN
    RAISE EXCEPTION 'cannot remove the last master administrator';
  END IF;

  UPDATE public.users
  SET role = p_role,
      is_master_admin = CASE WHEN p_role = 'admin' THEN is_master_admin ELSE false END
  WHERE employee_id = p_employee_id;
END;
$$;

CREATE OR REPLACE FUNCTION public.admin_set_master_admin(
  p_employee_id text,
  p_is_master boolean
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, public, auth
AS $$
DECLARE
  v_role text;
  v_current_master boolean;
BEGIN
  IF NOT public.is_master_admin() THEN
    RAISE EXCEPTION 'permission denied: master admin only';
  END IF;

  SELECT role, is_master_admin INTO v_role, v_current_master
  FROM public.users WHERE employee_id = p_employee_id FOR UPDATE;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'user not found: %', p_employee_id;
  END IF;
  IF p_is_master AND v_role <> 'admin' THEN
    RAISE EXCEPTION 'only role=admin can be a master administrator';
  END IF;
  IF p_is_master AND NOT v_current_master
     AND (SELECT count(*) FROM public.users WHERE is_master_admin) >= 4 THEN
    RAISE EXCEPTION 'at most four master administrators are allowed';
  END IF;
  IF NOT p_is_master AND v_current_master
     AND (SELECT count(*) FROM public.users WHERE is_master_admin) <= 1 THEN
    RAISE EXCEPTION 'cannot remove the last master administrator';
  END IF;

  UPDATE public.users
  SET is_master_admin = p_is_master
  WHERE employee_id = p_employee_id;
END;
$$;

-- A SECURITY DEFINER function must place pg_temp last explicitly; otherwise a
-- caller-created temporary object can be searched before trusted schemas.
-- The pre-existing externally callable/trigger functions are hardened here as
-- well, without changing their established signatures or behavior.
ALTER FUNCTION public.current_user_id()
  SET search_path = pg_catalog, public, auth, pg_temp;
ALTER FUNCTION public.is_admin()
  SET search_path = pg_catalog, public, auth, pg_temp;
ALTER FUNCTION public.is_admin_group()
  SET search_path = pg_catalog, public, auth, pg_temp;
ALTER FUNCTION public.is_master_admin()
  SET search_path = pg_catalog, public, auth, pg_temp;
ALTER FUNCTION public.is_current_asset_assignee(text)
  SET search_path = pg_catalog, public, auth, pg_temp;
ALTER FUNCTION public.is_inspection_participant(bigint)
  SET search_path = pg_catalog, public, auth, pg_temp;
ALTER FUNCTION public.is_legacy_agent()
  SET search_path = pg_catalog, public, auth, pg_temp;
ALTER FUNCTION public.claim_inspection_owner()
  SET search_path = pg_catalog, public, auth, pg_temp;
ALTER FUNCTION public.get_expiring_assets()
  SET search_path = pg_catalog, public, auth, pg_temp;
ALTER FUNCTION public.update_heartbeat(text, jsonb)
  SET search_path = pg_catalog, public, auth, pg_temp;
ALTER FUNCTION public.verify_user(text, text, text)
  SET search_path = pg_catalog, public, auth, pg_temp;
ALTER FUNCTION public.confirm_assignment(text, text)
  SET search_path = pg_catalog, public, auth, pg_temp;
ALTER FUNCTION public.request_inspection_recheck(bigint)
  SET search_path = pg_catalog, public, auth, pg_temp;
ALTER FUNCTION public.admin_reset_user_password_secure(text)
  SET search_path = pg_catalog, public, auth, extensions, pg_temp;
ALTER FUNCTION public.admin_create_user_secure(text, text, text, text, text)
  SET search_path = pg_catalog, public, auth, extensions, pg_temp;
ALTER FUNCTION public.admin_update_user_role(text, text)
  SET search_path = pg_catalog, public, auth, pg_temp;
ALTER FUNCTION public.admin_set_master_admin(text, boolean)
  SET search_path = pg_catalog, public, auth, pg_temp;
ALTER FUNCTION public.reset_inspection(bigint, text)
  SET search_path = pg_catalog, public, auth, pg_temp;
ALTER FUNCTION public.admin_force_verify(text)
  SET search_path = pg_catalog, public, auth, pg_temp;
ALTER FUNCTION public.start_inspection_round(bigint)
  SET search_path = pg_catalog, public, auth, pg_temp;
ALTER FUNCTION public.close_inspection_round(bigint)
  SET search_path = pg_catalog, public, auth, pg_temp;
ALTER FUNCTION public.reopen_inspection_round(bigint)
  SET search_path = pg_catalog, public, auth, pg_temp;
ALTER FUNCTION public.delete_inspection_round(bigint, boolean)
  SET search_path = pg_catalog, public, auth, pg_temp;
ALTER FUNCTION public.handle_new_user()
  SET search_path = pg_catalog, public, auth, pg_temp;
ALTER FUNCTION public.assets_master_user_change_trigger()
  SET search_path = pg_catalog, public, auth, pg_temp;

-- Future application objects are owned by postgres.  The existing default ACL
-- contained explicit grants to the API roles, so revoking PUBLIC alone is not
-- sufficient.  Remove both global and per-schema defaults: PostgreSQL's
-- built-in PUBLIC EXECUTE default for functions is global, while prior explicit
-- grants can be stored per schema.
DO $$
BEGIN
  IF current_user <> 'postgres' THEN
    RAISE EXCEPTION
      'security hardening must run as postgres (current_user is %)', current_user;
  END IF;
END;
$$;

ALTER DEFAULT PRIVILEGES FOR ROLE postgres
  REVOKE ALL PRIVILEGES ON TABLES FROM PUBLIC, anon, authenticated, service_role;
ALTER DEFAULT PRIVILEGES FOR ROLE postgres
  REVOKE ALL PRIVILEGES ON SEQUENCES FROM PUBLIC, anon, authenticated, service_role;
ALTER DEFAULT PRIVILEGES FOR ROLE postgres
  REVOKE ALL PRIVILEGES ON FUNCTIONS FROM PUBLIC, anon, authenticated, service_role;

ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA public
  REVOKE ALL PRIVILEGES ON TABLES FROM PUBLIC, anon, authenticated, service_role;
ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA public
  REVOKE ALL PRIVILEGES ON SEQUENCES FROM PUBLIC, anon, authenticated, service_role;
ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA public
  REVOKE ALL PRIVILEGES ON FUNCTIONS FROM PUBLIC, anon, authenticated, service_role;
ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA storage
  REVOKE ALL PRIVILEGES ON TABLES FROM PUBLIC, anon, authenticated, service_role;
ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA storage
  REVOKE ALL PRIVILEGES ON SEQUENCES FROM PUBLIC, anon, authenticated, service_role;
ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA storage
  REVOKE ALL PRIVILEGES ON FUNCTIONS FROM PUBLIC, anon, authenticated, service_role;

-- Create probes as the same owner that creates application objects.  Inspect
-- their effective ACLs, including PUBLIC (grantee oid 0), instead of relying
-- on an assumption about PostgreSQL's default ACL representation.  Any unsafe
-- default causes the transaction to fail before it can commit.
DROP FUNCTION IF EXISTS public._security_default_privilege_probe_function();
DROP FUNCTION IF EXISTS storage._security_default_privilege_probe_function();
DROP TABLE IF EXISTS public._security_default_privilege_probe_table;
DROP TABLE IF EXISTS storage._security_default_privilege_probe_table;
DROP SEQUENCE IF EXISTS public._security_default_privilege_probe_sequence;
DROP SEQUENCE IF EXISTS storage._security_default_privilege_probe_sequence;

CREATE FUNCTION public._security_default_privilege_probe_function()
RETURNS boolean
LANGUAGE sql
AS $$ SELECT true; $$;

CREATE FUNCTION storage._security_default_privilege_probe_function()
RETURNS boolean
LANGUAGE sql
AS $$ SELECT true; $$;

CREATE TABLE public._security_default_privilege_probe_table (
  id bigint PRIMARY KEY
);
CREATE TABLE storage._security_default_privilege_probe_table (
  id bigint PRIMARY KEY
);
CREATE SEQUENCE public._security_default_privilege_probe_sequence;
CREATE SEQUENCE storage._security_default_privilege_probe_sequence;

DO $$
DECLARE
  checked_role name;
BEGIN
  FOREACH checked_role IN ARRAY ARRAY['anon'::name, 'authenticated'::name, 'service_role'::name]
  LOOP
    IF EXISTS (
      SELECT 1
      FROM pg_proc AS p
      CROSS JOIN LATERAL aclexplode(
        COALESCE(p.proacl, acldefault('f', p.proowner))
      ) AS acl
      WHERE p.oid IN (
        'public._security_default_privilege_probe_function()'::regprocedure,
        'storage._security_default_privilege_probe_function()'::regprocedure
      )
        AND acl.grantee IN (0, checked_role::regrole)
    )
    OR EXISTS (
      SELECT 1
      FROM pg_class AS c
      CROSS JOIN LATERAL aclexplode(
        COALESCE(
          c.relacl,
          acldefault(CASE WHEN c.relkind = 'S' THEN 'S'::"char" ELSE 'r'::"char" END, c.relowner)
        )
      ) AS acl
      WHERE c.oid IN (
        'public._security_default_privilege_probe_table'::regclass,
        'storage._security_default_privilege_probe_table'::regclass,
        'public._security_default_privilege_probe_sequence'::regclass,
        'storage._security_default_privilege_probe_sequence'::regclass
      )
        AND acl.grantee IN (0, checked_role::regrole)
    ) THEN
      RAISE EXCEPTION 'unsafe postgres default ACL remains for role %', checked_role;
    END IF;
  END LOOP;
END;
$$;

DROP FUNCTION public._security_default_privilege_probe_function();
DROP FUNCTION storage._security_default_privilege_probe_function();
DROP TABLE public._security_default_privilege_probe_table;
DROP TABLE storage._security_default_privilege_probe_table;
DROP SEQUENCE public._security_default_privilege_probe_sequence;
DROP SEQUENCE storage._security_default_privilege_probe_sequence;

-- Revoke execution globally, then grant only the client RPC surface below.
-- Explicit anon/authenticated/service_role revocation clears prior direct
-- grants as well as the implicit PUBLIC grant.  Each sensitive function also
-- performs its own guard so a future GRANT cannot become a privilege bypass.
REVOKE EXECUTE ON ALL FUNCTIONS IN SCHEMA public
  FROM PUBLIC, anon, authenticated, service_role;
REVOKE EXECUTE ON FUNCTION public.admin_reset_user_password(text)
  FROM anon, authenticated, service_role;
REVOKE EXECUTE ON FUNCTION public.admin_create_user(text, text, text, text, text)
  FROM anon, authenticated, service_role;
REVOKE EXECUTE ON FUNCTION public.update_heartbeat(text, jsonb)
  FROM PUBLIC, anon, authenticated, service_role;
REVOKE EXECUTE ON FUNCTION public.verify_user(text, text, text)
  FROM PUBLIC, anon, authenticated, service_role;
REVOKE EXECUTE ON FUNCTION public.confirm_assignment(text, text)
  FROM PUBLIC, anon, authenticated, service_role;

GRANT EXECUTE ON FUNCTION public.current_user_id() TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.is_admin() TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.is_admin_group() TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.is_master_admin() TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.is_current_asset_assignee(text) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.is_inspection_participant(bigint) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.is_legacy_agent() TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.get_my_role() TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.get_expiring_assets() TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.request_inspection_recheck(bigint) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.reset_inspection(bigint, text) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.admin_force_verify(text) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.start_inspection_round(bigint) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.close_inspection_round(bigint) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.reopen_inspection_round(bigint) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.delete_inspection_round(bigint, boolean) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.admin_reset_user_password_secure(text) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.admin_create_user_secure(text, text, text, text, text) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.admin_update_user_role(text, text) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.admin_set_master_admin(text, boolean) TO authenticated, service_role;

COMMIT;

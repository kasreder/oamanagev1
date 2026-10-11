-- =============================================================================
-- OA Manager: private Realtime channels and assigned-data read boundaries
--
-- This is additive to 20260816000000_security_hardening.sql.  It deliberately
-- replaces broad application-table SELECT policies, adds the narrowly scoped
-- Realtime authorization policies needed for private channels, and leaves the
-- existing public-table mutation policies intact.
-- =============================================================================

BEGIN;

-- -----------------------------------------------------------------------------
-- 1. Read-scope helpers.  These SECURITY DEFINER functions are deliberately
--    small, stable predicates with a fixed search path.  They are used only by
--    RLS policies and never return the protected rows themselves.
-- -----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.has_current_asset_assignment()
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = pg_catalog, public, auth, pg_temp
AS $$
  SELECT EXISTS (
    SELECT 1
    FROM public.assets AS a
    WHERE a.user_id = public.current_user_id()
  );
$$;

CREATE OR REPLACE FUNCTION public.can_current_user_read_drawing(p_drawing_id bigint)
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = pg_catalog, public, auth, pg_temp
AS $$
  SELECT EXISTS (
    SELECT 1
    FROM public.assets AS a
    WHERE a.location_drawing_id = p_drawing_id
      AND a.user_id = public.current_user_id()
  );
$$;

CREATE OR REPLACE FUNCTION public.can_current_user_read_drawing_object(
  p_object_name text
)
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = pg_catalog, public, auth, pg_temp
AS $$
  SELECT COALESCE(p_object_name <> '', false)
    AND EXISTS (
      SELECT 1
      FROM public.assets AS a
      LEFT JOIN public.drawings AS d ON d.id = a.location_drawing_id
      WHERE a.user_id = public.current_user_id()
        AND (
          d.drawing_file = p_object_name
          -- Some imported legacy rows retain only the direct file reference.
          OR a.location_drawing_file = p_object_name
        )
    );
$$;

CREATE OR REPLACE FUNCTION public.can_current_user_read_inspection_photo(
  p_object_name text
)
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = pg_catalog, public, auth, pg_temp
AS $$
  SELECT COALESCE(p_object_name <> '', false)
    AND EXISTS (
      SELECT 1
      FROM public.asset_inspections AS ai
      LEFT JOIN public.assets AS a ON a.id = ai.asset_id
      WHERE ai.inspection_photo = p_object_name
        AND (
          ai.user_id = public.current_user_id()
          OR a.user_id = public.current_user_id()
        )
    );
$$;

CREATE OR REPLACE FUNCTION public.can_current_user_read_inspection_signature(
  p_object_name text
)
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = pg_catalog, public, auth, pg_temp
AS $$
  SELECT COALESCE(p_object_name <> '', false)
    AND EXISTS (
      SELECT 1
      FROM public.asset_inspections AS ai
      LEFT JOIN public.assets AS a ON a.id = ai.asset_id
      WHERE ai.signature_image = p_object_name
        AND (
          ai.user_id = public.current_user_id()
          OR a.user_id = public.current_user_id()
        )
    );
$$;

REVOKE ALL ON FUNCTION public.has_current_asset_assignment() FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.can_current_user_read_drawing(bigint) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.can_current_user_read_drawing_object(text) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.can_current_user_read_inspection_photo(text) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.can_current_user_read_inspection_signature(text) FROM PUBLIC, anon;

GRANT EXECUTE ON FUNCTION public.has_current_asset_assignment() TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.can_current_user_read_drawing(bigint) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.can_current_user_read_drawing_object(text) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.can_current_user_read_inspection_photo(text) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.can_current_user_read_inspection_signature(text) TO authenticated, service_role;

-- -----------------------------------------------------------------------------
-- 2. Public data and object reads.  Administrators/operators retain their
--    existing full-read role.  A regular account can read only records tied to
--    its assigned assets or inspections it owns/participates in.
-- -----------------------------------------------------------------------------
DROP POLICY IF EXISTS assets_select_authenticated ON public.assets;
DROP POLICY IF EXISTS assets_select_admin_or_assignee ON public.assets;
CREATE POLICY assets_select_admin_or_assignee ON public.assets
  FOR SELECT TO authenticated
  USING (
    public.is_admin_group()
    OR user_id = public.current_user_id()
  );

DROP POLICY IF EXISTS drawings_select_authenticated ON public.drawings;
DROP POLICY IF EXISTS drawings_select_admin_or_assignee ON public.drawings;
CREATE POLICY drawings_select_admin_or_assignee ON public.drawings
  FOR SELECT TO authenticated
  USING (
    public.is_admin_group()
    OR public.can_current_user_read_drawing(id)
  );

DROP POLICY IF EXISTS inspections_select_authenticated ON public.asset_inspections;
DROP POLICY IF EXISTS inspections_select_admin_or_participant ON public.asset_inspections;
CREATE POLICY inspections_select_admin_or_participant ON public.asset_inspections
  FOR SELECT TO authenticated
  USING (
    public.is_admin_group()
    OR public.is_inspection_participant(id)
  );

-- Agents already subscribe to notifications filtered by their asset UID.  The
-- previous admin-only SELECT policy made that documented flow unusable.  Keep
-- the administrator view while permitting only an assigned asset's notices.
DROP POLICY IF EXISTS notifications_select_admin_group ON public.notifications;
DROP POLICY IF EXISTS notifications_select_admin_or_assignee ON public.notifications;
CREATE POLICY notifications_select_admin_or_assignee ON public.notifications
  FOR SELECT TO authenticated
  USING (
    public.is_admin_group()
    OR public.is_current_asset_assignee(asset_uid)
  );

DROP POLICY IF EXISTS inspection_photos_select_authenticated ON storage.objects;
DROP POLICY IF EXISTS inspection_photos_select_admin_or_related ON storage.objects;
CREATE POLICY inspection_photos_select_admin_or_related ON storage.objects
  FOR SELECT TO authenticated
  USING (
    bucket_id = 'inspection-photos'
    AND (
      public.is_admin_group()
      -- Retain access to a caller's just-uploaded object before it is attached
      -- to its inspection row.  The write policy already constrains this path.
      OR (storage.foldername(name))[1] = auth.uid()::text
      OR public.can_current_user_read_inspection_photo(name)
    )
  );

DROP POLICY IF EXISTS inspection_signatures_select_authenticated ON storage.objects;
DROP POLICY IF EXISTS inspection_signatures_select_admin_or_related ON storage.objects;
CREATE POLICY inspection_signatures_select_admin_or_related ON storage.objects
  FOR SELECT TO authenticated
  USING (
    bucket_id = 'inspection-signatures'
    AND (
      public.is_admin_group()
      OR (storage.foldername(name))[1] = auth.uid()::text
      OR public.can_current_user_read_inspection_signature(name)
    )
  );

DROP POLICY IF EXISTS drawing_images_select_authenticated ON storage.objects;
DROP POLICY IF EXISTS drawing_images_select_admin_or_assignee ON storage.objects;
CREATE POLICY drawing_images_select_admin_or_assignee ON storage.objects
  FOR SELECT TO authenticated
  USING (
    bucket_id = 'drawing-images'
    AND (
      public.is_admin_group()
      OR public.can_current_user_read_drawing_object(name)
    )
  );

-- -----------------------------------------------------------------------------
-- 3. Realtime Broadcast/Presence authorization.
--
-- The Realtime server evaluates both Broadcast and Presence SELECT permissions
-- when a private channel is joined, including channels that only use Postgres
-- Changes.  The Postgres-Changes topic grants below do not grant a client
-- any table rows; normal table RLS remains the delivery boundary.
-- -----------------------------------------------------------------------------
DROP POLICY IF EXISTS oa_realtime_postgres_changes_read ON realtime.messages;
DROP POLICY IF EXISTS oa_realtime_agent_notifications_read ON realtime.messages;
DROP POLICY IF EXISTS oa_realtime_presence_read ON realtime.messages;
DROP POLICY IF EXISTS oa_realtime_commands_read_assignee ON realtime.messages;
DROP POLICY IF EXISTS oa_realtime_alerts_read_admin ON realtime.messages;
DROP POLICY IF EXISTS oa_realtime_presence_write_assignee ON realtime.messages;
DROP POLICY IF EXISTS oa_realtime_commands_write_admin ON realtime.messages;

CREATE POLICY oa_realtime_postgres_changes_read ON realtime.messages
  FOR SELECT TO authenticated
  USING (
    extension IN ('broadcast', 'presence')
    AND (SELECT realtime.topic()) IN ('assets-realtime', 'inspections-realtime')
  );

CREATE POLICY oa_realtime_agent_notifications_read ON realtime.messages
  FOR SELECT TO authenticated
  USING (
    extension IN ('broadcast', 'presence')
    AND split_part((SELECT realtime.topic()), ':', 1) = 'notifications'
    AND split_part((SELECT realtime.topic()), ':', 3) = ''
    AND public.is_current_asset_assignee(
      split_part((SELECT realtime.topic()), ':', 2)
    )
  );

-- Realtime v2.34.47 requires Broadcast read permission to join a private
-- Presence channel.  This necessarily permits authenticated assignees to see
-- the deliberately minimal global presence payload; do not add user/asset
-- details beyond the existing asset UID field to this topic.
CREATE POLICY oa_realtime_presence_read ON realtime.messages
  FOR SELECT TO authenticated
  USING (
    extension IN ('broadcast', 'presence')
    AND (SELECT realtime.topic()) = 'agent-presence:global'
    AND (
      public.is_admin_group()
      OR public.has_current_asset_assignment()
    )
  );

CREATE POLICY oa_realtime_commands_read_assignee ON realtime.messages
  FOR SELECT TO authenticated
  USING (
    extension IN ('broadcast', 'presence')
    AND split_part((SELECT realtime.topic()), ':', 1) = 'agent-commands'
    AND split_part((SELECT realtime.topic()), ':', 3) = ''
    AND public.is_current_asset_assignee(
      split_part((SELECT realtime.topic()), ':', 2)
    )
  );

-- The UI subscribes to operational alerts only for the administrator group.
-- Agent-originated global alert joins are removed from the client source below,
-- so normal agents never receive that topic.
CREATE POLICY oa_realtime_alerts_read_admin ON realtime.messages
  FOR SELECT TO authenticated
  USING (
    extension IN ('broadcast', 'presence')
    AND (SELECT realtime.topic()) = 'agent-alerts:global'
    AND public.is_admin_group()
  );

CREATE POLICY oa_realtime_presence_write_assignee ON realtime.messages
  FOR INSERT TO authenticated
  WITH CHECK (
    extension = 'presence'
    AND (SELECT realtime.topic()) = 'agent-presence:global'
    AND public.has_current_asset_assignment()
  );

CREATE POLICY oa_realtime_commands_write_admin ON realtime.messages
  FOR INSERT TO authenticated
  WITH CHECK (
    extension = 'broadcast'
    AND split_part((SELECT realtime.topic()), ':', 1) = 'agent-commands'
    AND split_part((SELECT realtime.topic()), ':', 3) = ''
    AND public.is_admin_group()
  );

-- Realtime's self-hosted setting is named private_only.  Its tenant metadata
-- is owned by the Realtime service, not the application migration role, so the
-- compose startup command reapplies it after the default tenant seed.

COMMIT;

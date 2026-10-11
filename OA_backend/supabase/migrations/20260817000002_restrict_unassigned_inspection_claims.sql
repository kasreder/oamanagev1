-- P1 remediation: an active, unassigned inspection may only be claimed by the
-- employee assigned to its source asset.  The prior policy and trigger checked
-- the inspection's owner but not the asset's assignee, allowing any ordinary
-- authenticated user who knew an inspection ID to claim it.

BEGIN;

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

  -- A non-administrator cannot claim or edit an inspection unless the source
  -- asset itself is assigned to that account.  This intentionally fails closed
  -- for unassigned assets and NULL asset references.
  IF NOT EXISTS (
    SELECT 1
    FROM public.assets AS a
    WHERE a.id = OLD.asset_id
      AND a.user_id = v_user_id
  ) THEN
    RAISE EXCEPTION 'forbidden: inspection asset is not assigned to caller';
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

DROP POLICY IF EXISTS inspections_update_claimed_active ON public.asset_inspections;
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
        SELECT 1
        FROM public.inspection_rounds AS r
        WHERE r.id = asset_inspections.round_id
          AND r.status = 'active'
      )
      AND EXISTS (
        SELECT 1
        FROM public.assets AS a
        WHERE a.id = asset_inspections.asset_id
          AND a.user_id = public.current_user_id()
      )
    )
  )
  WITH CHECK (
    public.is_admin()
    OR (
      user_id = public.current_user_id()
      AND EXISTS (
        SELECT 1
        FROM public.inspection_rounds AS r
        WHERE r.id = asset_inspections.round_id
          AND r.status = 'active'
      )
      AND EXISTS (
        SELECT 1
        FROM public.assets AS a
        WHERE a.id = asset_inspections.asset_id
          AND a.user_id = public.current_user_id()
      )
    )
  );

COMMIT;

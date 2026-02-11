-- OA Manager v1
-- inspection permission policy + reset RPC

BEGIN;

-- 1) Admin helper by JWT custom claim
CREATE OR REPLACE FUNCTION public.is_admin()
RETURNS boolean
LANGUAGE sql
STABLE
AS $$
  SELECT COALESCE((auth.jwt() ->> 'is_admin')::boolean, false);
$$;

-- 2) Restrict updates on completed inspections for non-admin users
DROP POLICY IF EXISTS "inspections_update" ON public.asset_inspections;
CREATE POLICY "inspections_update" ON public.asset_inspections
  FOR UPDATE TO authenticated
  USING (
    public.is_admin()
    OR NOT (
      inspection_building IS NOT NULL
      AND inspection_floor IS NOT NULL
      AND inspection_position IS NOT NULL
      AND inspection_photo IS NOT NULL
      AND signature_image IS NOT NULL
    )
  )
  WITH CHECK (
    public.is_admin()
    OR NOT (
      inspection_building IS NOT NULL
      AND inspection_floor IS NOT NULL
      AND inspection_position IS NOT NULL
      AND inspection_photo IS NOT NULL
      AND signature_image IS NOT NULL
    )
  );

-- 3) Admin-only reset RPC
CREATE OR REPLACE FUNCTION public.reset_inspection(
  p_inspection_id bigint,
  p_reason text DEFAULT NULL
)
RETURNS public.asset_inspections
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_row public.asset_inspections;
BEGIN
  IF NOT public.is_admin() THEN
    RAISE EXCEPTION 'forbidden: admin only';
  END IF;

  UPDATE public.asset_inspections
  SET
    status = NULL,
    memo = p_reason,
    inspection_photo = NULL,
    signature_image = NULL,
    synced = false,
    updated_at = now()
  WHERE id = p_inspection_id
  RETURNING * INTO v_row;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'inspection not found: %', p_inspection_id;
  END IF;

  RETURN v_row;
END;
$$;

REVOKE ALL ON FUNCTION public.reset_inspection(bigint, text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.reset_inspection(bigint, text) TO authenticated;

COMMIT;


-- =============================================================================
-- OA Manager: keep floor-plan images private
--
-- A public Storage bucket bypasses object RLS for direct object URLs. Recreate
-- the drawing bucket policy set as authenticated-only and force the bucket
-- itself private. The DROP/CREATE sequence makes this safe to re-run.
-- =============================================================================

BEGIN;

INSERT INTO storage.buckets (id, name, public)
VALUES ('drawing-images', 'drawing-images', false)
ON CONFLICT (id) DO UPDATE
SET public = false;

ALTER TABLE storage.objects ENABLE ROW LEVEL SECURITY;

-- Remove both the legacy anonymous policy names and the hardened names before
-- recreating the approved policy set below.
DROP POLICY IF EXISTS drawing_images_select ON storage.objects;
DROP POLICY IF EXISTS drawing_images_select_authenticated ON storage.objects;
DROP POLICY IF EXISTS drawing_images_insert ON storage.objects;
DROP POLICY IF EXISTS drawing_images_update ON storage.objects;
DROP POLICY IF EXISTS drawing_images_delete ON storage.objects;
DROP POLICY IF EXISTS drawing_images_insert_admin_group ON storage.objects;
DROP POLICY IF EXISTS drawing_images_update_admin_group ON storage.objects;
DROP POLICY IF EXISTS drawing_images_delete_admin_group ON storage.objects;

CREATE POLICY drawing_images_select_authenticated ON storage.objects
  FOR SELECT TO authenticated
  USING (bucket_id = 'drawing-images');

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

-- Fail closed if the postconditions above ever drift. In addition to the four
-- approved policies, reject any drawing-specific policy that grants anon or
-- PUBLIC access.
DO $$
DECLARE
  approved_policy_count integer;
BEGIN
  IF (SELECT b.public FROM storage.buckets AS b WHERE b.id = 'drawing-images')
       IS DISTINCT FROM false THEN
    RAISE EXCEPTION 'drawing-images bucket must be private';
  END IF;

  IF NOT (SELECT c.relrowsecurity
          FROM pg_class AS c
          WHERE c.oid = 'storage.objects'::regclass) THEN
    RAISE EXCEPTION 'storage.objects row level security must be enabled';
  END IF;

  SELECT count(*)
    INTO approved_policy_count
  FROM pg_policies
  WHERE schemaname = 'storage'
    AND tablename = 'objects'
    AND policyname IN (
      'drawing_images_select_authenticated',
      'drawing_images_insert_admin_group',
      'drawing_images_update_admin_group',
      'drawing_images_delete_admin_group'
    )
    AND roles = ARRAY['authenticated'::name];

  IF approved_policy_count <> 4 THEN
    RAISE EXCEPTION 'drawing-images authenticated-only policies are incomplete';
  END IF;

  IF EXISTS (
    SELECT 1
    FROM pg_policy AS p
    JOIN pg_class AS c ON c.oid = p.polrelid
    JOIN pg_namespace AS n ON n.oid = c.relnamespace
    WHERE n.nspname = 'storage'
      AND c.relname = 'objects'
      AND (
        COALESCE(pg_get_expr(p.polqual, p.polrelid), '') LIKE '%drawing-images%'
        OR COALESCE(pg_get_expr(p.polwithcheck, p.polrelid), '') LIKE '%drawing-images%'
      )
      AND (
        p.polroles = ARRAY[0]::oid[]
        OR 'anon'::regrole::oid = ANY (p.polroles)
      )
  ) THEN
    RAISE EXCEPTION 'anonymous drawing-images storage policy remains';
  END IF;
END;
$$;

COMMIT;

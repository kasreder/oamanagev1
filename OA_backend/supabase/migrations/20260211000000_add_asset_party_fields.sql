-- OA Manager v1
-- Add owner/user/admin info fields to assets

BEGIN;

ALTER TABLE public.assets
  ADD COLUMN IF NOT EXISTS owner_name text,
  ADD COLUMN IF NOT EXISTS owner_department text,
  ADD COLUMN IF NOT EXISTS user_name text,
  ADD COLUMN IF NOT EXISTS user_department text,
  ADD COLUMN IF NOT EXISTS admin_name text,
  ADD COLUMN IF NOT EXISTS admin_department text;

-- Legacy compatibility: if old member_name exists, copy to admin_name when empty.
DO $$
BEGIN
  IF EXISTS (
    SELECT 1
    FROM information_schema.columns
    WHERE table_schema = 'public'
      AND table_name = 'assets'
      AND column_name = 'member_name'
  ) THEN
    UPDATE public.assets
    SET admin_name = COALESCE(admin_name, member_name)
    WHERE member_name IS NOT NULL;
  END IF;
END
$$;

COMMIT;


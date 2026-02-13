-- OA Manager v1
-- asset_uid format alignment migration
-- Target format: [B|R|C|L|S][DT|NB|MN|PR|TB|SC|IP|NW|SV|WR|SD][0-9]{5}

BEGIN;

-- 1) Remove legacy auto-generation behavior (OA-{YEAR}-{SEQ})
DROP TRIGGER IF EXISTS auto_asset_uid ON public.assets;
DROP FUNCTION IF EXISTS public.generate_asset_uid();

-- 2) Validate and normalize asset_uid on every INSERT/UPDATE
CREATE OR REPLACE FUNCTION public.validate_asset_uid()
RETURNS trigger
LANGUAGE plpgsql
AS $$
BEGIN
  IF NEW.asset_uid IS NULL OR btrim(NEW.asset_uid) = '' THEN
    RAISE EXCEPTION 'asset_uid is required';
  END IF;

  -- Normalize input to avoid casing/whitespace drift
  NEW.asset_uid := upper(btrim(NEW.asset_uid));

  IF NEW.asset_uid !~ '^(B|R|C|L|S)(DT|NB|MN|PR|TB|SC|IP|NW|SV|WR|SD)[0-9]{5}$' THEN
    RAISE EXCEPTION 'invalid asset_uid format: %', NEW.asset_uid
      USING HINT = 'Expected format: [B|R|C|L|S][DT|NB|MN|PR|TB|SC|IP|NW|SV|WR|SD][0-9]{5}';
  END IF;

  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS validate_asset_uid ON public.assets;
CREATE TRIGGER validate_asset_uid
BEFORE INSERT OR UPDATE ON public.assets
FOR EACH ROW
EXECUTE FUNCTION public.validate_asset_uid();

-- 3) Add named CHECK constraint for schema-level consistency.
--    NOT VALID prevents migration failure on pre-existing legacy rows.
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1
    FROM pg_constraint
    WHERE conname = 'chk_assets_asset_uid_format'
      AND conrelid = 'public.assets'::regclass
  ) THEN
    ALTER TABLE public.assets
      ADD CONSTRAINT chk_assets_asset_uid_format
      CHECK (asset_uid ~ '^(B|R|C|L|S)(DT|NB|MN|PR|TB|SC|IP|NW|SV|WR|SD)[0-9]{5}$')
      NOT VALID;
  END IF;
END
$$;

COMMIT;

-- ---- Post-deploy verification (run manually) ----
-- 1) Legacy rows check:
-- SELECT id, asset_uid
-- FROM public.assets
-- WHERE asset_uid !~ '^(B|R|C|L|S)(DT|NB|MN|PR|TB|SC|IP|NW|SV|WR|SD)[0-9]{5}$';
--
-- 2) After legacy rows are fixed, enforce for all rows:
-- ALTER TABLE public.assets VALIDATE CONSTRAINT chk_assets_asset_uid_format;


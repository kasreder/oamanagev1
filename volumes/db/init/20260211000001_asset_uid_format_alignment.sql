-- OA Manager v1
-- asset_uid format alignment migration
-- 현재기준: D00001, TP0001 등 (문자1~2자리 + 숫자4~5자리)
-- 변경후: BDT00001, STP22222 등 (등록경로1자리 + 장비코드2자리 + 일련번호5자리)

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

  -- 현재기준 (D00001, TP0001 등) + 변경후 (BDT00001 등) 둘 다 허용
  IF NEW.asset_uid !~ '^([A-Z]{1,2}[0-9]{4,5}|(B|R|C|L|S)(DT|NB|MN|PR|TB|SC|IP|NW|SV|WR|SD|TP|ET|EH)[0-9]{5})$' THEN
    RAISE EXCEPTION 'invalid asset_uid format: %', NEW.asset_uid
      USING HINT = 'Current: D00001, TP0001 / New: BDT00001, STP22222';
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
      CHECK (asset_uid ~ '^([A-Z]{1,2}[0-9]{4,5}|(B|R|C|L|S)(DT|NB|MN|PR|TB|SC|IP|NW|SV|WR|SD|TP|ET|EH)[0-9]{5})$')
      NOT VALID;
  END IF;
END
$$;

COMMIT;

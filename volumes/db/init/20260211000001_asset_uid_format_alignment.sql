-- OA Manager v1
-- asset_uid 형식 검증 — 옛 형식 단일 (D00001, TP0001 등: 영문 1~2자리 + 숫자 4~5자리)

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

  IF NEW.asset_uid !~ '^[A-Z]{1,2}[0-9]{4,5}$' THEN
    RAISE EXCEPTION 'invalid asset_uid format: %', NEW.asset_uid
      USING HINT = '허용 형식: D00001, TP0001, NW00012 (영문 1~2자리 + 숫자 4~5자리)';
  END IF;

  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS validate_asset_uid ON public.assets;
CREATE TRIGGER validate_asset_uid
BEFORE INSERT OR UPDATE ON public.assets
FOR EACH ROW
EXECUTE FUNCTION public.validate_asset_uid();

COMMIT;

-- =============================================================================
-- asset_uid: 현재기준 + 변경후 두 형식 병행 허용
--
-- 현재기준: D00001, TP0001, NW00012 (영문 1~2자리 + 숫자 4~5자리)
-- 변경후:   BDT00001, STP22222 (등록경로 B|R|C|L|S + 장비코드 2자리 + 숫자 5자리)
-- 20260614000003에서 폐기했던 변경후 형식을 다시 허용한다. 데이터 변경 없음.
-- 클라이언트 정규식: OA_frontend/oa_app/lib/constants.dart assetUidRegex
-- =============================================================================

BEGIN;

ALTER TABLE public.assets
  DROP CONSTRAINT IF EXISTS assets_asset_uid_check;

ALTER TABLE public.assets
  ADD CONSTRAINT assets_asset_uid_check
  CHECK (asset_uid ~ '^([A-Z]{1,2}[0-9]{4,5}|(B|R|C|L|S)(DT|NB|MN|PR|TB|SC|IP|NW|SV|WR|SD|TP|ET|EH)[0-9]{5})$');

CREATE OR REPLACE FUNCTION public.validate_asset_uid()
RETURNS trigger
LANGUAGE plpgsql
AS $$
BEGIN
  IF NEW.asset_uid IS NULL OR btrim(NEW.asset_uid) = '' THEN
    RAISE EXCEPTION 'asset_uid is required';
  END IF;

  NEW.asset_uid := upper(btrim(NEW.asset_uid));

  IF NEW.asset_uid !~ '^([A-Z]{1,2}[0-9]{4,5}|(B|R|C|L|S)(DT|NB|MN|PR|TB|SC|IP|NW|SV|WR|SD|TP|ET|EH)[0-9]{5})$' THEN
    RAISE EXCEPTION 'invalid asset_uid format: %', NEW.asset_uid
      USING HINT = '허용 형식: D00001, TP0001 (영문 1~2 + 숫자 4~5) 또는 BDT00001 (등록경로 1 + 장비코드 2 + 숫자 5)';
  END IF;

  RETURN NEW;
END;
$$;

COMMIT;

-- =============================================================================
-- asset_uid: 변경후 기준(BDT00001 등) 폐기 — 옛 형식만 허용
--
-- 옛 형식: D00001, TP0001, NW00012 등 (영문 1~2자리 + 숫자 4~5자리)
-- DB 전수 조사 결과 변경후 형식은 0건 → 데이터 마이그레이션 없음.
-- =============================================================================

BEGIN;

-- 1) 통합 CHECK 제거 (init이 만든 이름)
ALTER TABLE public.assets
  DROP CONSTRAINT IF EXISTS assets_asset_uid_check;

-- 2) 별도 명명 CHECK도 제거 (alignment migration이 만든 것)
ALTER TABLE public.assets
  DROP CONSTRAINT IF EXISTS chk_assets_asset_uid_format;

-- 3) 옛 형식만 허용하는 CHECK 재정의
ALTER TABLE public.assets
  ADD CONSTRAINT assets_asset_uid_check
  CHECK (asset_uid ~ '^[A-Z]{1,2}[0-9]{4,5}$');

-- 4) trigger 함수 갱신 (옛 형식만)
CREATE OR REPLACE FUNCTION public.validate_asset_uid()
RETURNS trigger
LANGUAGE plpgsql
AS $$
BEGIN
  IF NEW.asset_uid IS NULL OR btrim(NEW.asset_uid) = '' THEN
    RAISE EXCEPTION 'asset_uid is required';
  END IF;

  NEW.asset_uid := upper(btrim(NEW.asset_uid));

  IF NEW.asset_uid !~ '^[A-Z]{1,2}[0-9]{4,5}$' THEN
    RAISE EXCEPTION 'invalid asset_uid format: %', NEW.asset_uid
      USING HINT = '허용 형식: D00001, TP0001, NW00012 (영문 1~2자리 + 숫자 4~5자리)';
  END IF;

  RETURN NEW;
END;
$$;

COMMIT;

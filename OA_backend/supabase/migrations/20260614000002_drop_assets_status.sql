-- =============================================================================
-- assets_status 컬럼 완전 제거
--
-- 사유: UI에서 "상태"를 supply_type(지급형태)로 일원화. assets_status는 더 이상
--      입력/표시되지 않으므로 인덱스/체크제약과 함께 컬럼 자체를 제거한다.
-- =============================================================================

DROP INDEX IF EXISTS public.idx_assets_status;

ALTER TABLE public.assets
  DROP COLUMN IF EXISTS assets_status;

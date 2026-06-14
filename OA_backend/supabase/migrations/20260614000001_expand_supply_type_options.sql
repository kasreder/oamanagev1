-- =============================================================================
-- supply_type 옵션 확장 + 사용망 옵션 권장값 문서화
--
-- 신규 옵션: 이동, 폐기, 도급, 개인 (기존: 지급/렌탈/대여/창고(대기)/창고(점검))
-- 만료일 필수는 UI에서만 검증 (렌탈/대여/도급/개인일 때)
-- =============================================================================

ALTER TABLE public.assets
  DROP CONSTRAINT IF EXISTS assets_supply_type_check;

ALTER TABLE public.assets
  ADD CONSTRAINT assets_supply_type_check
  CHECK (supply_type = ANY (ARRAY[
    '지급'::text, '렌탈'::text, '대여'::text,
    '이동'::text, '창고(대기)'::text, '창고(점검)'::text,
    '폐기'::text, '도급'::text, '개인'::text
  ]));

-- 네트워크 컬럼은 자유 텍스트 유지 (UI에서 권장 옵션 노출). CHECK 추가 X.
COMMENT ON COLUMN public.assets.network IS
  '사용망 — 권장 옵션: 업무망/개발망/시스템망/인터넷망/셀룰러 (자유 입력 허용)';

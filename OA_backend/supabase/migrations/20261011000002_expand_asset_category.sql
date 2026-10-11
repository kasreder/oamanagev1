-- =============================================================================
-- assets.category CHECK 확장: 12종 → 14종
--
-- 앱(OA_frontend/oa_app/lib/constants.dart assetCategories)은 '현장업무 태블릿',
-- '법인폰'을 선택할 수 있으나 DB CHECK(20240201000002)는 12종만 허용해 저장이
-- 실패할 수 있었다. 앱 목록과 동일하게 맞춘다. 데이터 변경 없음.
--
-- 참고: 라이브 DB(oa-db)에는 2026-10-11 확인 시 이미 14종 CHECK 가 직접 반영돼
-- 있었다. 이 파일은 저장소(SoT)를 라이브와 일치시키기 위한 기록이며, 새 환경
-- (supabase db reset 등)에서 동일 상태를 재현한다. 라이브 재적용은 결과 동일.
-- =============================================================================

BEGIN;

ALTER TABLE public.assets
  DROP CONSTRAINT IF EXISTS assets_category_check;

ALTER TABLE public.assets
  ADD CONSTRAINT assets_category_check
  CHECK (category IN (
    '데스크탑', '모니터', '노트북', 'IP전화기', '스캐너', '프린터',
    '태블릿', '테스트폰', '네트워크장비', '서버', '웨어러블', '특수목적장비',
    '현장업무 태블릿', '법인폰'
  ));

COMMIT;

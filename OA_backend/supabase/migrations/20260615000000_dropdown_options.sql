-- =============================================================================
-- 드롭다운 옵션 통합 테이블
--
-- scope: 어느 페이지에서 노출되는지 (asset_detail / asset_list / inspection_list / inspection_detail)
-- category: 드롭다운 식별자 (category / supply_type / network / building1 / admin_affiliation / inspection_status)
-- value:    옵션 텍스트 (UI 표시 = DB 저장 값)
--
-- 같은 category는 여러 scope에 동시에 노출될 수 있음 (자산상세/목록 공유 등) — UI는 scope별로 필터링하여 표시.
-- =============================================================================

BEGIN;

CREATE TABLE IF NOT EXISTS public.dropdown_options (
  id          bigserial PRIMARY KEY,
  scope       text NOT NULL,
  category    text NOT NULL,
  value       text NOT NULL,
  sort_order  int  NOT NULL DEFAULT 0,
  created_at  timestamptz DEFAULT now(),
  updated_at  timestamptz DEFAULT now(),
  UNIQUE(scope, category, value)
);

CREATE INDEX IF NOT EXISTS idx_dropdown_options_scope_cat
  ON public.dropdown_options(scope, category, sort_order);

ALTER TABLE public.dropdown_options ENABLE ROW LEVEL SECURITY;

-- 모두 SELECT 가능 (admin/일반 동일)
DROP POLICY IF EXISTS dropdown_options_select ON public.dropdown_options;
CREATE POLICY dropdown_options_select ON public.dropdown_options
  FOR SELECT TO authenticated USING (true);

-- admin 그룹만 INSERT/UPDATE/DELETE
DROP POLICY IF EXISTS dropdown_options_write ON public.dropdown_options;
CREATE POLICY dropdown_options_write ON public.dropdown_options
  FOR ALL TO authenticated
  USING (public.is_admin_group())
  WITH CHECK (public.is_admin_group());

-- =============================================================================
-- Seed: 현재 constants.dart의 const 리스트들을 그대로 옮김
-- =============================================================================

WITH seed AS (
  SELECT * FROM (VALUES
    -- 자산상세/자산목록: 자산종류 (14)
    ('asset_detail','category','데스크탑',           1),
    ('asset_detail','category','모니터',             2),
    ('asset_detail','category','노트북',             3),
    ('asset_detail','category','IP전화기',           4),
    ('asset_detail','category','스캐너',             5),
    ('asset_detail','category','프린터',             6),
    ('asset_detail','category','태블릿',             7),
    ('asset_detail','category','테스트폰',           8),
    ('asset_detail','category','네트워크장비',       9),
    ('asset_detail','category','서버',               10),
    ('asset_detail','category','웨어러블',           11),
    ('asset_detail','category','특수목적장비',       12),
    ('asset_detail','category','현장업무 태블릿',    13),
    ('asset_detail','category','법인폰',             14),
    -- 자산상세/자산목록: 지급형태 (9)
    ('asset_detail','supply_type','지급',            1),
    ('asset_detail','supply_type','렌탈',            2),
    ('asset_detail','supply_type','대여',            3),
    ('asset_detail','supply_type','이동',            4),
    ('asset_detail','supply_type','창고(대기)',      5),
    ('asset_detail','supply_type','창고(점검)',      6),
    ('asset_detail','supply_type','폐기',            7),
    ('asset_detail','supply_type','도급',            8),
    ('asset_detail','supply_type','개인',            9),
    -- 자산상세: 사용망 (5)
    ('asset_detail','network','업무망',              1),
    ('asset_detail','network','개발망',              2),
    ('asset_detail','network','시스템망',            3),
    ('asset_detail','network','인터넷망',            4),
    ('asset_detail','network','셀룰러',              5),
    -- 자산상세: 건물(대) (5)
    ('asset_detail','building1','콘코디언',          1),
    ('asset_detail','building1','부영',              2),
    ('asset_detail','building1','태평로',            3),
    ('asset_detail','building1','국제',              4),
    ('asset_detail','building1','센터 및 지점',      5),
    -- 자산상세: 담당자 소속 (2)
    ('asset_detail','admin_affiliation','롯데카드',  1),
    ('asset_detail','admin_affiliation','롯데카드 외',2),
    -- 실사상세/실사목록: 실사 상태 (4)
    ('inspection_detail','inspection_status','이상없음',         1),
    ('inspection_detail','inspection_status','반납요청(미사용)', 2),
    ('inspection_detail','inspection_status','반납요청(사용자변경)',3),
    ('inspection_detail','inspection_status','재확인 필요',      4)
  ) AS t(scope, category, value, sort_order)
)
INSERT INTO public.dropdown_options(scope, category, value, sort_order)
SELECT scope, category, value, sort_order FROM seed
ON CONFLICT (scope, category, value) DO NOTHING;

COMMIT;

-- =============================================================================
-- 자산 검색 성능 인덱스
--
-- ilike 와일드카드 검색을 빠르게 처리하기 위한 pg_trgm GIN 인덱스
-- + 자주 검색되는 b-tree 컬럼 인덱스.
-- 20K 자산 기준 추가 디스크 ~30MB, ilike 200ms → ~20ms 추정.
-- =============================================================================

CREATE EXTENSION IF NOT EXISTS pg_trgm;

-- ilike '%값%' 가속용 trigram GIN
CREATE INDEX IF NOT EXISTS idx_assets_name_trgm
  ON public.assets USING gin (name gin_trgm_ops);
CREATE INDEX IF NOT EXISTS idx_assets_user_name_trgm
  ON public.assets USING gin (user_name gin_trgm_ops);
CREATE INDEX IF NOT EXISTS idx_assets_serial_trgm
  ON public.assets USING gin (serial_number gin_trgm_ops);
CREATE INDEX IF NOT EXISTS idx_assets_owner_name_trgm
  ON public.assets USING gin (owner_name gin_trgm_ops);
CREATE INDEX IF NOT EXISTS idx_assets_admin_name_trgm
  ON public.assets USING gin (admin_name gin_trgm_ops);
CREATE INDEX IF NOT EXISTS idx_assets_user_employee_id_trgm
  ON public.assets USING gin (user_employee_id gin_trgm_ops);
CREATE INDEX IF NOT EXISTS idx_assets_user_department_trgm
  ON public.assets USING gin (user_department gin_trgm_ops);
CREATE INDEX IF NOT EXISTS idx_assets_owner_department_trgm
  ON public.assets USING gin (owner_department gin_trgm_ops);
CREATE INDEX IF NOT EXISTS idx_assets_admin_department_trgm
  ON public.assets USING gin (admin_department gin_trgm_ops);

-- eq용 b-tree
CREATE INDEX IF NOT EXISTS idx_assets_user_employee_id
  ON public.assets (user_employee_id);
CREATE INDEX IF NOT EXISTS idx_assets_vendor
  ON public.assets (vendor);
CREATE INDEX IF NOT EXISTS idx_assets_model_name
  ON public.assets (model_name);
CREATE INDEX IF NOT EXISTS idx_assets_floor
  ON public.assets (floor);

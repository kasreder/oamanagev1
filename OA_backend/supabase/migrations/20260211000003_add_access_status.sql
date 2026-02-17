-- OA Manager v1
-- 접속현황 기능: assets.last_active_at 컬럼 + access_settings 테이블

BEGIN;

-- ── 1. assets 테이블에 last_active_at 컬럼 추가 ─────────────────────────
ALTER TABLE public.assets
  ADD COLUMN IF NOT EXISTS last_active_at timestamptz;

CREATE INDEX IF NOT EXISTS idx_assets_last_active
  ON public.assets(last_active_at);

-- ── 2. access_settings 테이블 생성 ───────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.access_settings (
  id            bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  setting_key   text UNIQUE NOT NULL,
  setting_value int NOT NULL,
  description   text,
  created_at    timestamptz DEFAULT now(),
  updated_at    timestamptz DEFAULT now()
);

-- 기본 데이터 삽입
INSERT INTO public.access_settings (setting_key, setting_value, description)
VALUES
  ('active_threshold_minutes', 60, '실시간 접속 판단 기준 (분). 이 시간 이내 활동 시 초록색 표시'),
  ('warning_threshold_days', 31, '경과일 표시 최대 일수. 초과 시 빨간색(만료) 표시')
ON CONFLICT (setting_key) DO NOTHING;

-- updated_at 자동 갱신 트리거
CREATE TRIGGER set_updated_at
  BEFORE UPDATE ON public.access_settings
  FOR EACH ROW
  EXECUTE FUNCTION handle_updated_at();

-- ── 3. access_settings RLS 정책 ──────────────────────────────────────────
ALTER TABLE public.access_settings ENABLE ROW LEVEL SECURITY;

-- 비인증 포함: 설정값 조회 가능 (프론트엔드에서 임계값 참조)
CREATE POLICY "access_settings_select" ON public.access_settings
  FOR SELECT TO anon, authenticated
  USING (true);

-- 인증된 사용자(관리자): 설정값 수정
CREATE POLICY "access_settings_update" ON public.access_settings
  FOR UPDATE TO authenticated
  USING (public.is_admin())
  WITH CHECK (public.is_admin());

COMMIT;

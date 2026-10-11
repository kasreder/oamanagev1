-- 메뉴 권한 관리: 대상(모든유저/그룹/개인)별 "보이는 메뉴 키 목록"
-- 행이 없으면 기본(전부 보임). 평가 우선순위: user > role > all > 기본.
-- admin 계정은 프론트에서 항상 전부 보임(잠금 방지).

BEGIN;

CREATE TABLE IF NOT EXISTS public.menu_permissions (
  id           bigserial PRIMARY KEY,
  target_type  text NOT NULL CHECK (target_type IN ('all','role','user')),
  target_value text NOT NULL DEFAULT '',   -- role명 또는 employee_id, all이면 ''
  menu_keys    text[] NOT NULL DEFAULT '{}',
  updated_at   timestamptz NOT NULL DEFAULT now(),
  UNIQUE (target_type, target_value)
);

CREATE TRIGGER trg_menu_permissions_updated_at
  BEFORE UPDATE ON public.menu_permissions
  FOR EACH ROW EXECUTE FUNCTION public.handle_updated_at();

ALTER TABLE public.menu_permissions ENABLE ROW LEVEL SECURITY;

-- 모두 읽기(자기 메뉴 계산), 쓰기는 admin만
CREATE POLICY menu_permissions_select ON public.menu_permissions
  FOR SELECT TO authenticated USING (true);
CREATE POLICY menu_permissions_write ON public.menu_permissions
  FOR ALL TO authenticated
  USING (public.is_admin()) WITH CHECK (public.is_admin());

GRANT SELECT, INSERT, UPDATE, DELETE ON public.menu_permissions TO authenticated;
GRANT ALL ON public.menu_permissions TO service_role;
GRANT USAGE, SELECT ON SEQUENCE public.menu_permissions_id_seq TO authenticated, service_role;

COMMIT;

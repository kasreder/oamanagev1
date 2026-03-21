-- users 테이블에 role 컬럼 추가
-- 역할: admin(관리자), operator1(운영자1), operator2(운영자2), user(사용자)
ALTER TABLE public.users ADD COLUMN IF NOT EXISTS role text NOT NULL DEFAULT 'user'
  CHECK (role IN ('admin', 'operator1', 'operator2', 'user'));

-- 기존 is_admin() 함수를 role 기반으로 교체
CREATE OR REPLACE FUNCTION public.is_admin()
RETURNS boolean
LANGUAGE sql
STABLE
AS $$
  SELECT EXISTS (
    SELECT 1 FROM public.users
    WHERE auth_uid = auth.uid()
      AND role = 'admin'
  );
$$;

-- 관리자 그룹 (admin, operator1, operator2) 확인 함수
CREATE OR REPLACE FUNCTION public.is_admin_group()
RETURNS boolean
LANGUAGE sql
STABLE
AS $$
  SELECT EXISTS (
    SELECT 1 FROM public.users
    WHERE auth_uid = auth.uid()
      AND role IN ('admin', 'operator1', 'operator2')
  );
$$;

-- 현재 사용자의 role 반환 함수
CREATE OR REPLACE FUNCTION public.get_my_role()
RETURNS text
LANGUAGE sql
STABLE
AS $$
  SELECT role FROM public.users
  WHERE auth_uid = auth.uid()
  LIMIT 1;
$$;

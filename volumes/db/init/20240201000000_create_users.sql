-- OA Manager v1
-- 4.2 users (사원 정보) 테이블 생성

CREATE TABLE public.users (
  id            bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  auth_uid      uuid REFERENCES auth.users(id) ON DELETE SET NULL,
  employee_id   text UNIQUE NOT NULL,
  employee_name text NOT NULL,
  employment_type text NOT NULL DEFAULT '정규직'
    CHECK (employment_type IN ('정규직', '계약직', '도급직')),
  organization_hq   text,
  organization_dept text,
  organization_team text,
  organization_part text,
  organization_etc  text,
  work_building text,
  work_floor    text,
  auth_provider text DEFAULT 'email'
    CHECK (auth_provider IN ('email', 'kakao', 'google')),
  sns_id        text,
  created_at    timestamptz DEFAULT now(),
  updated_at    timestamptz DEFAULT now()
);
CREATE INDEX idx_users_auth_uid ON public.users(auth_uid);
CREATE INDEX idx_users_employee_id ON public.users(employee_id);

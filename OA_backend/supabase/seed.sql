-- OA Manager v1 development seed data
-- Temporary test account (id: temp01, password: Temp1234!)
--
-- Usage:
-- 1) Create auth user first in Supabase Auth (service-role required).
-- 2) Run seed migration (db reset/push) to sync public.users.

INSERT INTO public.users (
  employee_id,
  employee_name,
  employment_type,
  organization_hq,
  organization_dept,
  organization_team,
  organization_part,
  organization_etc,
  work_building,
  work_floor,
  auth_provider
) VALUES (
  'temp01',
  'Test User',
  '정규직',
  'HQ',
  'Development',
  'Development Team',
  'Demo',
  'N/A',
  'HQ Building',
  '3F',
  'email'
)
ON CONFLICT (employee_id) DO UPDATE SET
  employee_name = EXCLUDED.employee_name,
  employment_type = EXCLUDED.employment_type,
  organization_hq = EXCLUDED.organization_hq,
  organization_dept = EXCLUDED.organization_dept,
  organization_team = EXCLUDED.organization_team,
  organization_part = EXCLUDED.organization_part,
  organization_etc = EXCLUDED.organization_etc,
  work_building = EXCLUDED.work_building,
  work_floor = EXCLUDED.work_floor,
  auth_provider = EXCLUDED.auth_provider,
  updated_at = now();

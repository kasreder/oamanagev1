# 임시 테스트 계정 안내

로컬/개발 환경에서 바로 로그인 확인할 수 있도록 테스트 계정 정보를 별도 문서와 시드로 관리합니다.

## 1) 미리 적용된 계정 정보(예시)

- 사번(employee_id): `7`
- 로그인 이메일: `temp01@oamanager.internal`
- 비밀번호: `Temp1234!`
- 사용 위치: `OA_backend/supabase/seed.sql`

## 2) 로그인 절차

1. Supabase Auth에 `temp01@oamanager.internal` 계정을 생성합니다.
2. `OA_backend/supabase/seed.sql`을 통해 `public.users`의 `temp01` 행을 반영합니다.
3. 앱 로그인을 다음 값으로 시도합니다.
   - ID: `temp01`
   - PASSWORD: `Temp1234!`

## 3) Auth 계정 생성 SQL (예시)

```sql
INSERT INTO auth.users (
  id,
  instance_id,
  aud,
  role,
  email,
  encrypted_password,
  email_confirmed_at,
  confirmation_token,
  recovery_token,
  email_change_token_new,
  email_change,
  phone_change_token,
  email_change_token_current,
  reauthentication_token,
  raw_app_meta_data,
  raw_user_meta_data,
  created_at,
  updated_at
)
SELECT
  gen_random_uuid(),
  '00000000-0000-0000-0000-000000000000'::uuid,
  'authenticated',
  'authenticated',
  'temp01@oamanager.internal',
  crypt('Temp1234!', gen_salt('bf')),
  NOW(),
  '',  -- confirmation_token (NULL이면 GoTrue 500 에러)
  '',  -- recovery_token
  '',  -- email_change_token_new
  '',  -- email_change
  '',  -- phone_change_token
  '',  -- email_change_token_current
  '',  -- reauthentication_token
  '{}'::jsonb,
  jsonb_build_object(
    'employee_id', 'temp01',
    'employee_name', '임시 계정',
    'employment_type', '정규직'
  ),
  NOW(),
  NOW()
WHERE NOT EXISTS (
  SELECT 1 FROM auth.users WHERE email = 'temp01@oamanager.internal'
);
```

> `gen_random_uuid()`/`crypt()`는 PostgreSQL/pgcrypto 기본 함수를 사용합니다.
> `auth.users`에 `CREATE USER`를 위한 전용 RPC가 있는 환경에서는 해당 API를 우선 사용해도 됩니다.

## 4) 시드 적용 확인

```sql
SELECT employee_id, employee_name, employment_type
FROM public.users
WHERE employee_id = 'temp01';
```

---

- 시드 파일 위치: `OA_backend/supabase/seed.sql`
- 시드 적용: `supabase db reset` 또는 `supabase db reset --linked` 후 확인

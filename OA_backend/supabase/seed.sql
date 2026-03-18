-- =============================================================================
-- OA Manager v1 — 테스트 시드 데이터
-- 테스트 계정: temp01 / Temp1234!
--
-- 사용법:
--   supabase db reset     ← 마이그레이션 + 시드 자동 실행
--
-- 동작 순서:
--   1. auth.users에 계정 생성 (고정 UUID 사용)
--   2. handle_new_user 트리거 → public.users 자동 생성
--   3. public.users 보완 UPDATE (조직 정보 등)
-- =============================================================================

-- 고정 UUID (재실행 시 중복 방지)
DO $$
DECLARE
  v_uid uuid := '00000000-0000-0000-0000-000000000001';
BEGIN
  -- 기존 계정이 있으면 삭제 후 재생성
  DELETE FROM auth.users WHERE id = v_uid;

  -- 1) auth.users에 테스트 계정 생성
  INSERT INTO auth.users (
    id,
    instance_id,
    aud,
    role,
    email,
    encrypted_password,
    email_confirmed_at,
    raw_app_meta_data,
    raw_user_meta_data,
    created_at,
    updated_at,
    confirmation_token,
    recovery_token,
    email_change,
    email_change_token_new,
    email_change_token_current,
    email_change_confirm_status,
    phone,
    phone_change,
    phone_change_token,
    reauthentication_token,
    is_sso_user
  ) VALUES (
    v_uid,
    '00000000-0000-0000-0000-000000000000',
    'authenticated',
    'authenticated',
    'temp01@oamanager.internal',
    crypt('Temp1234!', gen_salt('bf')),
    now(),
    '{"provider": "email", "providers": ["email"]}'::jsonb,
    jsonb_build_object(
      'employee_id',       'temp01',
      'employee_name',     'Test User',
      'employment_type',   '정규직',
      'organization_hq',   'IT본부',
      'organization_dept',  '개발부',
      'organization_team',  '플랫폼팀',
      'organization_part',  '',
      'organization_etc',   '',
      'work_building',      '본관',
      'work_floor',         '3F',
      'auth_provider',      'email'
    ),
    now(),
    now(),
    '',   -- confirmation_token
    '',   -- recovery_token
    '',   -- email_change (GoTrue는 NULL 불가)
    '',   -- email_change_token_new
    '',   -- email_change_token_current
    0,    -- email_change_confirm_status
    '',   -- phone
    '',   -- phone_change
    '',   -- phone_change_token
    '',   -- reauthentication_token
    false -- is_sso_user
  );

  -- 2) auth.identities 레코드 생성 (Supabase Auth 필수)
  INSERT INTO auth.identities (
    id,
    user_id,
    provider_id,
    identity_data,
    provider,
    last_sign_in_at,
    created_at,
    updated_at
  ) VALUES (
    v_uid,
    v_uid,
    'temp01@oamanager.internal',
    jsonb_build_object(
      'sub', v_uid::text,
      'email', 'temp01@oamanager.internal',
      'email_verified', true
    ),
    'email',
    now(),
    now(),
    now()
  )
  ON CONFLICT (provider_id, provider) DO NOTHING;

  -- 3) handle_new_user 트리거가 public.users를 자동 생성하므로,
  --    보완이 필요한 필드만 UPDATE
  UPDATE public.users
  SET
    organization_hq   = 'IT본부',
    organization_dept  = '개발부',
    organization_team  = '플랫폼팀',
    work_building      = '본관',
    work_floor         = '3F'
  WHERE employee_id = 'temp01';

END;
$$;

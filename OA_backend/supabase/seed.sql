-- =============================================================================
-- OA Manager v1 — 테스트 시드 데이터
--
-- 계정 목록:
--   관리자 그룹: temp01(admin), admin01(admin), oper01(operator1), oper02(operator2)
--   사용자 그룹: user01~user05(user)
--   비밀번호: 각 계정별 아래 참조
--
-- 사용법:
--   supabase db reset     ← 마이그레이션 + 시드 자동 실행
--
-- 동작 순서:
--   1. auth.users에 계정 생성 (고정 UUID 사용)
--   2. handle_new_user 트리거 → public.users 자동 생성
--   3. public.users 보완 UPDATE (조직 정보, role 등)
-- =============================================================================

-- 헬퍼 함수: 계정 1건 생성
CREATE OR REPLACE FUNCTION _seed_create_user(
  p_uid uuid,
  p_employee_id text,
  p_employee_name text,
  p_password text,
  p_employment_type text,
  p_org_hq text,
  p_org_dept text,
  p_org_team text,
  p_work_building text,
  p_work_floor text,
  p_role text
) RETURNS void AS $$
BEGIN
  -- 기존 계정 삭제 후 재생성
  DELETE FROM auth.users WHERE id = p_uid;

  INSERT INTO auth.users (
    id, instance_id, aud, role, email, encrypted_password,
    email_confirmed_at, raw_app_meta_data, raw_user_meta_data,
    created_at, updated_at,
    confirmation_token, recovery_token, email_change,
    email_change_token_new, email_change_token_current,
    email_change_confirm_status, phone, phone_change,
    phone_change_token, reauthentication_token, is_sso_user
  ) VALUES (
    p_uid,
    '00000000-0000-0000-0000-000000000000',
    'authenticated', 'authenticated',
    p_employee_id || '@oamanager.internal',
    crypt(p_password, gen_salt('bf')),
    now(),
    '{"provider": "email", "providers": ["email"]}'::jsonb,
    jsonb_build_object(
      'employee_id',      p_employee_id,
      'employee_name',    p_employee_name,
      'employment_type',  p_employment_type,
      'organization_hq',  p_org_hq,
      'organization_dept', p_org_dept,
      'organization_team', p_org_team,
      'organization_part', '',
      'organization_etc',  '',
      'work_building',     p_work_building,
      'work_floor',        p_work_floor,
      'auth_provider',     'email'
    ),
    now(), now(),
    '', '', '', '', '', 0, '', '', '', '', false
  );

  INSERT INTO auth.identities (
    id, user_id, provider_id, identity_data, provider,
    last_sign_in_at, created_at, updated_at
  ) VALUES (
    p_uid, p_uid,
    p_employee_id || '@oamanager.internal',
    jsonb_build_object(
      'sub', p_uid::text,
      'email', p_employee_id || '@oamanager.internal',
      'email_verified', true
    ),
    'email', now(), now(), now()
  ) ON CONFLICT (provider_id, provider) DO NOTHING;

  -- handle_new_user 트리거가 public.users를 자동 생성하므로 보완 UPDATE
  UPDATE public.users SET
    organization_hq   = p_org_hq,
    organization_dept  = p_org_dept,
    organization_team  = p_org_team,
    work_building      = p_work_building,
    work_floor         = p_work_floor,
    role               = p_role
  WHERE employee_id = p_employee_id;
END;
$$ LANGUAGE plpgsql;

-- =============================================================================
-- 계정 생성
-- =============================================================================
DO $$
BEGIN
  -- ── 관리자 그룹 ──
  -- temp01: 기존 테스트 계정 (admin)
  PERFORM _seed_create_user(
    '00000000-0000-0000-0000-000000000001',
    'temp01', 'Test User', 'Temp1234!', '정규직',
    'IT본부', '개발부', '플랫폼팀', '본관', '3F', 'admin'
  );

  -- admin01: 관리자
  PERFORM _seed_create_user(
    '00000000-0000-0000-0000-000000000002',
    'admin01', '관리자', 'Admin1234!', '정규직',
    'IT본부', '운영부', '인프라팀', '본관', '5F', 'admin'
  );

  -- oper01: 운영자1
  PERFORM _seed_create_user(
    '00000000-0000-0000-0000-000000000003',
    'oper01', '운영자1', 'Oper1234!', '정규직',
    'IT본부', '운영부', '인프라팀', '본관', '5F', 'operator1'
  );

  -- oper02: 운영자2
  PERFORM _seed_create_user(
    '00000000-0000-0000-0000-000000000004',
    'oper02', '운영자2', 'Oper1234!', '정규직',
    'IT본부', '운영부', '자산팀', '본관', '5F', 'operator2'
  );

  -- ── 사용자 그룹 ──
  -- user01
  PERFORM _seed_create_user(
    '00000000-0000-0000-0000-000000000011',
    'user01', '사용자1', 'User1234!', '정규직',
    '경영본부', '총무부', '총무팀', '본관', '2F', 'user'
  );

  -- user02
  PERFORM _seed_create_user(
    '00000000-0000-0000-0000-000000000012',
    'user02', '사용자2', 'User1234!', '정규직',
    '경영본부', '인사부', '인사팀', '본관', '2F', 'user'
  );

  -- user03
  PERFORM _seed_create_user(
    '00000000-0000-0000-0000-000000000013',
    'user03', '사용자3', 'User1234!', '계약직',
    '기술본부', '기술부', '기술1팀', '별관', '3F', 'user'
  );

  -- user04
  PERFORM _seed_create_user(
    '00000000-0000-0000-0000-000000000014',
    'user04', '사용자4', 'User1234!', '정규직',
    '기술본부', '기술부', '기술2팀', '별관', '4F', 'user'
  );

  -- user05
  PERFORM _seed_create_user(
    '00000000-0000-0000-0000-000000000015',
    'user05', '사용자5', 'User1234!', '도급직',
    '영업본부', '영업부', '영업팀', '본관', '1F', 'user'
  );
END;
$$;

-- 헬퍼 함수 정리
DROP FUNCTION IF EXISTS _seed_create_user;

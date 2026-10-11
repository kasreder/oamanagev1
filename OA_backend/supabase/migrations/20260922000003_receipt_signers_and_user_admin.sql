-- OA Manager v1
-- 1) users.receipt_team (helpdesk / it_plan) — 인수증 서명 담당자 드롭다운 소스
-- 2) users.must_change_password — 관리자가 비번 설정 시 다음 로그인에서 강제 변경
-- 3) receipts 서명 메타 (거래처 담당자명 / 발송업체 표기 / 헬프데스크·IT기획팀 담당자)
-- 4) 인수증·거래처 RLS: admin group(admin/operator1/operator2)만
-- 5) 사용자 관리 RPC: 관리자(role=admin)도 운영자/일반 등급·계정 생성·비번 설정 가능
--    (admin 등급 부여/변경/비번 리셋은 여전히 마스터만)

BEGIN;

-- ── 1,2) users 컬럼 ─────────────────────────────────────────────────
ALTER TABLE public.users
  ADD COLUMN IF NOT EXISTS receipt_team text
    CHECK (receipt_team IN ('helpdesk', 'it_plan')),
  ADD COLUMN IF NOT EXISTS must_change_password boolean NOT NULL DEFAULT false;

-- ── 3) receipts 서명 메타 ───────────────────────────────────────────
ALTER TABLE public.receipts
  ADD COLUMN IF NOT EXISTS sign_vendor_name       text,
  ADD COLUMN IF NOT EXISTS sign_vendor_as_sender  boolean NOT NULL DEFAULT false,
  ADD COLUMN IF NOT EXISTS sign_helpdesk_user_id  bigint REFERENCES public.users(id) ON DELETE SET NULL,
  ADD COLUMN IF NOT EXISTS sign_it_plan_user_id   bigint REFERENCES public.users(id) ON DELETE SET NULL;

-- ── 4) RLS: 인수증/거래처 → admin group only ────────────────────────
DROP POLICY IF EXISTS vendors_select ON public.vendors;
CREATE POLICY vendors_select ON public.vendors
  FOR SELECT TO authenticated USING (public.is_admin_group());

DROP POLICY IF EXISTS receipts_select ON public.receipts;
DROP POLICY IF EXISTS receipts_insert ON public.receipts;
DROP POLICY IF EXISTS receipts_update ON public.receipts;
CREATE POLICY receipts_select ON public.receipts
  FOR SELECT TO authenticated USING (public.is_admin_group());
CREATE POLICY receipts_insert ON public.receipts
  FOR INSERT TO authenticated WITH CHECK (public.is_admin_group());
CREATE POLICY receipts_update ON public.receipts
  FOR UPDATE TO authenticated
  USING (public.is_admin_group()) WITH CHECK (public.is_admin_group());

DROP POLICY IF EXISTS receipt_items_select ON public.receipt_items;
DROP POLICY IF EXISTS receipt_items_insert ON public.receipt_items;
DROP POLICY IF EXISTS receipt_items_update ON public.receipt_items;
DROP POLICY IF EXISTS receipt_items_delete ON public.receipt_items;
CREATE POLICY receipt_items_select ON public.receipt_items
  FOR SELECT TO authenticated USING (public.is_admin_group());
CREATE POLICY receipt_items_insert ON public.receipt_items
  FOR INSERT TO authenticated WITH CHECK (public.is_admin_group());
CREATE POLICY receipt_items_update ON public.receipt_items
  FOR UPDATE TO authenticated
  USING (public.is_admin_group()) WITH CHECK (public.is_admin_group());
CREATE POLICY receipt_items_delete ON public.receipt_items
  FOR DELETE TO authenticated USING (public.is_admin_group());

DROP POLICY IF EXISTS "receipt_signatures_all" ON storage.objects;
CREATE POLICY "receipt_signatures_all" ON storage.objects
  FOR ALL TO authenticated
  USING (bucket_id = 'receipt-signatures' AND public.is_admin_group())
  WITH CHECK (bucket_id = 'receipt-signatures' AND public.is_admin_group());

DROP POLICY IF EXISTS "receipt_assets_all" ON storage.objects;
CREATE POLICY "receipt_assets_all" ON storage.objects
  FOR ALL TO authenticated
  USING (bucket_id = 'receipt-assets' AND public.is_admin_group())
  WITH CHECK (bucket_id = 'receipt-assets' AND public.is_admin_group());

-- ── 5a) role 변경: admin은 user/operator*만, master는 전부 ───────────
CREATE OR REPLACE FUNCTION public.admin_update_user_role(p_employee_id text, p_role text)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'pg_catalog', 'public', 'auth', 'pg_temp'
AS $$
DECLARE
  v_is_master boolean;
  v_role text;
BEGIN
  IF NOT public.is_admin() THEN
    RAISE EXCEPTION 'permission denied: admin only';
  END IF;
  IF p_role NOT IN ('user', 'admin', 'operator1', 'operator2') THEN
    RAISE EXCEPTION 'invalid role: %', p_role;
  END IF;

  SELECT is_master_admin, role INTO v_is_master, v_role
  FROM public.users WHERE employee_id = p_employee_id FOR UPDATE;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'user not found: %', p_employee_id;
  END IF;

  IF NOT public.is_master_admin() THEN
    IF p_role = 'admin' THEN
      RAISE EXCEPTION 'only master admin can grant admin role';
    END IF;
    IF v_role = 'admin' OR v_is_master THEN
      RAISE EXCEPTION 'only master admin can change an admin account';
    END IF;
  END IF;

  IF v_is_master AND p_role <> 'admin'
     AND (SELECT count(*) FROM public.users WHERE is_master_admin) <= 1 THEN
    RAISE EXCEPTION 'cannot remove the last master administrator';
  END IF;

  UPDATE public.users
  SET role = p_role,
      is_master_admin = CASE WHEN p_role = 'admin' THEN is_master_admin ELSE false END
  WHERE employee_id = p_employee_id;
END;
$$;

-- ── 5b) 계정 생성: admin 가능(admin 등급은 master만). 비번 직접 입력 옵션 ─
DROP FUNCTION IF EXISTS public.admin_create_user_secure(text, text, text, text, text);
CREATE OR REPLACE FUNCTION public.admin_create_user_secure(
  p_employee_id   text,
  p_employee_name text,
  p_role          text DEFAULT 'user',
  p_org_dept      text DEFAULT NULL,
  p_email         text DEFAULT NULL,
  p_password      text DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'pg_catalog', 'public', 'auth', 'extensions', 'pg_temp'
AS $$
DECLARE
  v_auth_uid uuid := gen_random_uuid();
  v_email text;
  v_password text;
  v_typed boolean := p_password IS NOT NULL AND length(btrim(p_password)) > 0;
  v_id bigint;
BEGIN
  IF NOT public.is_admin() THEN
    RAISE EXCEPTION 'permission denied: admin only';
  END IF;
  IF p_role = 'admin' AND NOT public.is_master_admin() THEN
    RAISE EXCEPTION 'only master admin can create an admin account';
  END IF;
  IF p_employee_id IS NULL OR length(btrim(p_employee_id)) = 0 THEN
    RAISE EXCEPTION 'employee_id is required';
  END IF;
  IF p_employee_name IS NULL OR length(btrim(p_employee_name)) = 0 THEN
    RAISE EXCEPTION 'employee_name is required';
  END IF;
  IF p_role NOT IN ('user', 'admin', 'operator1', 'operator2') THEN
    RAISE EXCEPTION 'invalid role: %', p_role;
  END IF;
  IF v_typed AND length(btrim(p_password)) < 8 THEN
    RAISE EXCEPTION 'password must be at least 8 characters';
  END IF;
  IF EXISTS (SELECT 1 FROM public.users WHERE employee_id = p_employee_id) THEN
    RAISE EXCEPTION 'employee_id % already exists', p_employee_id;
  END IF;

  v_email := COALESCE(p_email, p_employee_id || '@oamanager.internal');
  v_password := CASE WHEN v_typed THEN btrim(p_password)
                     ELSE 'OA-' || encode(extensions.gen_random_bytes(12), 'hex') END;

  INSERT INTO auth.users (
    id, instance_id, aud, role, email, encrypted_password, email_confirmed_at,
    raw_app_meta_data, raw_user_meta_data, created_at, updated_at
  ) VALUES (
    v_auth_uid, '00000000-0000-0000-0000-000000000000',
    'authenticated', 'authenticated', v_email,
    extensions.crypt(v_password, extensions.gen_salt('bf')), now(),
    jsonb_build_object('provider', 'email', 'providers', jsonb_build_array('email')),
    jsonb_build_object(
      'employee_id', p_employee_id,
      'employee_name', p_employee_name,
      'organization_dept', p_org_dept,
      'auth_provider', 'email'
    ),
    now(), now()
  );

  INSERT INTO auth.identities (
    id, user_id, provider_id, identity_data, provider,
    last_sign_in_at, created_at, updated_at
  ) VALUES (
    v_auth_uid, v_auth_uid, v_email,
    jsonb_build_object('sub', v_auth_uid::text, 'email', v_email, 'email_verified', true),
    'email', now(), now(), now()
  ) ON CONFLICT (provider_id, provider) DO NOTHING;

  -- handle_new_user() 트리거가 프로필 생성. 이후 role/부서/강제변경 플래그만 갱신.
  UPDATE public.users
  SET role = p_role,
      organization_dept = p_org_dept,
      must_change_password = true
  WHERE auth_uid = v_auth_uid
  RETURNING id INTO v_id;

  IF v_id IS NULL THEN
    RAISE EXCEPTION 'profile provisioning failed for %', p_employee_id;
  END IF;

  RETURN jsonb_build_object(
    'user_id', v_id,
    'employee_id', p_employee_id,
    'temporary_password', CASE WHEN v_typed THEN NULL ELSE v_password END
  );
END;
$$;

-- ── 5c) 비번 설정(관리자 직접 입력) + 다음 로그인 강제 변경 여부 ─────
CREATE OR REPLACE FUNCTION public.admin_set_user_password(
  p_employee_id  text,
  p_new_password text,
  p_force_change boolean DEFAULT true
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'pg_catalog', 'public', 'auth', 'extensions', 'pg_temp'
AS $$
DECLARE
  v_auth_uid uuid;
  v_role text;
  v_is_master boolean;
BEGIN
  IF NOT public.is_admin() THEN
    RAISE EXCEPTION 'permission denied: admin only';
  END IF;
  IF p_new_password IS NULL OR length(btrim(p_new_password)) < 8 THEN
    RAISE EXCEPTION 'password must be at least 8 characters';
  END IF;

  SELECT auth_uid, role, is_master_admin INTO v_auth_uid, v_role, v_is_master
  FROM public.users WHERE employee_id = p_employee_id;
  IF v_auth_uid IS NULL THEN
    RAISE EXCEPTION 'user % has no auth account', p_employee_id;
  END IF;
  IF (v_role = 'admin' OR v_is_master) AND NOT public.is_master_admin() THEN
    RAISE EXCEPTION 'only master admin can reset an admin password';
  END IF;

  UPDATE auth.users
  SET encrypted_password = extensions.crypt(btrim(p_new_password), extensions.gen_salt('bf')),
      banned_until = NULL,
      updated_at = now()
  WHERE id = v_auth_uid;

  UPDATE public.users
  SET must_change_password = p_force_change
  WHERE employee_id = p_employee_id;
END;
$$;

-- ── 5d) 본인 강제 변경 플래그 해제 (비번 자체는 GoTrue updateUser로) ──
CREATE OR REPLACE FUNCTION public.clear_must_change_password()
RETURNS void
LANGUAGE sql
SECURITY DEFINER
SET search_path TO 'pg_catalog', 'public', 'pg_temp'
AS $$
  UPDATE public.users SET must_change_password = false WHERE auth_uid = auth.uid();
$$;

-- ── 5e) 인수증 서명 팀 지정 ─────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.admin_set_receipt_team(p_employee_id text, p_team text)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'pg_catalog', 'public', 'pg_temp'
AS $$
BEGIN
  IF NOT public.is_admin() THEN
    RAISE EXCEPTION 'permission denied: admin only';
  END IF;
  IF p_team IS NOT NULL AND p_team NOT IN ('helpdesk', 'it_plan') THEN
    RAISE EXCEPTION 'invalid team: %', p_team;
  END IF;
  UPDATE public.users SET receipt_team = p_team WHERE employee_id = p_employee_id;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'user not found: %', p_employee_id;
  END IF;
END;
$$;

REVOKE ALL ON FUNCTION public.admin_create_user_secure(text,text,text,text,text,text) FROM public;
GRANT EXECUTE ON FUNCTION public.admin_create_user_secure(text,text,text,text,text,text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.admin_set_user_password(text,text,boolean) TO authenticated;
GRANT EXECUTE ON FUNCTION public.clear_must_change_password() TO authenticated;
GRANT EXECUTE ON FUNCTION public.admin_set_receipt_team(text,text) TO authenticated;

COMMIT;

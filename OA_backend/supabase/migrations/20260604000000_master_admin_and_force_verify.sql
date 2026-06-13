-- =============================================================================
-- 마스터 관리자 + 강제 재확인(admin_force_verify) + 알림 Realtime 발송
-- =============================================================================
-- 푸시 전략: Firebase 미사용. notifications 테이블 INSERT 이벤트를
--           Supabase Realtime publication으로 발송하여 에이전트가 구독.
-- =============================================================================

-- 1) users.is_master_admin 컬럼
ALTER TABLE public.users
  ADD COLUMN IF NOT EXISTS is_master_admin boolean NOT NULL DEFAULT false;

CREATE INDEX IF NOT EXISTS idx_users_is_master_admin
  ON public.users(is_master_admin) WHERE is_master_admin = true;

-- 2) 제약 트리거 — 최대 4명, role='admin'만
CREATE OR REPLACE FUNCTION public.enforce_master_admin_constraints()
RETURNS trigger AS $$
DECLARE
  v_count integer;
BEGIN
  IF NEW.is_master_admin = true THEN
    IF NEW.role <> 'admin' THEN
      RAISE EXCEPTION '마스터 관리자는 role=admin 인 사용자만 지정 가능합니다 (대상: %, 현재 role: %)',
        NEW.employee_id, NEW.role;
    END IF;

    SELECT count(*) INTO v_count
    FROM public.users
    WHERE is_master_admin = true
      AND id <> NEW.id;

    IF v_count >= 4 THEN
      RAISE EXCEPTION '마스터 관리자는 최대 4명까지 지정 가능합니다 (현재: %명)', v_count;
    END IF;
  END IF;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_enforce_master_admin ON public.users;
CREATE TRIGGER trg_enforce_master_admin
  BEFORE INSERT OR UPDATE OF is_master_admin, role ON public.users
  FOR EACH ROW
  EXECUTE FUNCTION public.enforce_master_admin_constraints();

-- 3) admin01을 기본 마스터로 설정
UPDATE public.users
SET is_master_admin = true
WHERE employee_id = 'admin01' AND is_master_admin = false;

-- 4) is_master_admin() 헬퍼
CREATE OR REPLACE FUNCTION public.is_master_admin()
RETURNS boolean
LANGUAGE sql STABLE SECURITY DEFINER
AS $$
  SELECT EXISTS (
    SELECT 1 FROM public.users
    WHERE auth_uid = auth.uid()
      AND is_master_admin = true
      AND role = 'admin'
  );
$$;

-- 5) admin_force_verify RPC
CREATE OR REPLACE FUNCTION public.admin_force_verify(p_asset_uid text)
RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER
AS $$
DECLARE
  v_found boolean;
BEGIN
  IF NOT public.is_admin() THEN
    RAISE EXCEPTION '권한 없음: 관리자만 강제 재확인 가능합니다';
  END IF;

  UPDATE public.assets
  SET verification_status = NULL,
      last_verified_at    = NULL,
      specifications      = specifications - 'user_mismatch'
  WHERE asset_uid = p_asset_uid
  RETURNING true INTO v_found;

  IF NOT v_found THEN
    RAISE EXCEPTION '자산을 찾을 수 없음: %', p_asset_uid;
  END IF;

  INSERT INTO public.notifications (asset_uid, type, title, body)
  VALUES (
    p_asset_uid,
    'general',
    '사용자 재확인 요청',
    '관리자 요청으로 사용자 확인이 초기화되었습니다. 에이전트 앱에서 다시 확인을 진행해주세요.'
  );

  RETURN jsonb_build_object(
    'asset_uid', p_asset_uid,
    'reset', true,
    'requested_at', now()
  );
END;
$$;

GRANT EXECUTE ON FUNCTION public.admin_force_verify(text) TO authenticated;

-- 6) assets UPDATE 트리거 — 마스터 관리자가 user_name 변경 시 자동 재확인 요청
CREATE OR REPLACE FUNCTION public.assets_master_user_change_trigger()
RETURNS trigger
LANGUAGE plpgsql SECURITY DEFINER
AS $$
BEGIN
  IF NEW.user_name IS DISTINCT FROM OLD.user_name
     AND public.is_master_admin() THEN

    NEW.verification_status := NULL;
    NEW.last_verified_at    := NULL;
    NEW.specifications      := NEW.specifications - 'user_mismatch';

    INSERT INTO public.notifications (asset_uid, type, title, body)
    VALUES (
      NEW.asset_uid,
      'general',
      '사용자 재확인 요청 (자동)',
      format(
        '마스터 관리자가 실사용자를 %s → %s 으로 변경했습니다. 에이전트 앱에서 다시 사용자 확인을 진행해주세요.',
        COALESCE(OLD.user_name, '(미지정)'),
        COALESCE(NEW.user_name, '(미지정)')
      )
    );
  END IF;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_assets_master_user_change ON public.assets;
CREATE TRIGGER trg_assets_master_user_change
  BEFORE UPDATE OF user_name ON public.assets
  FOR EACH ROW
  EXECUTE FUNCTION public.assets_master_user_change_trigger();

-- 7) notifications 테이블을 Realtime publication에 추가
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_publication_tables
    WHERE pubname='supabase_realtime' AND schemaname='public' AND tablename='notifications'
  ) THEN
    EXECUTE 'ALTER PUBLICATION supabase_realtime ADD TABLE public.notifications';
  END IF;
END;
$$;

-- =============================================================================
-- 끝
-- =============================================================================

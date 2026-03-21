-- 전사 실사 라운드(차수) 관리 테이블
-- 관리자 그룹이 년도별 실사 차수를 생성/시작/종료
CREATE TABLE public.inspection_rounds (
  id          bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  year        int NOT NULL,
  round       int NOT NULL,                    -- 차수 (1, 2, 3...)
  title       text NOT NULL,                   -- 예: '2026년 1차 실사'
  status      text NOT NULL DEFAULT 'draft'
    CHECK (status IN ('draft', 'active', 'closed')),
  started_by  bigint REFERENCES public.users(id),
  started_at  timestamptz,
  closed_by   bigint REFERENCES public.users(id),
  closed_at   timestamptz,
  created_at  timestamptz DEFAULT now(),
  updated_at  timestamptz DEFAULT now(),
  UNIQUE(year, round)
);

-- updated_at 트리거
CREATE TRIGGER set_updated_at_inspection_rounds
  BEFORE UPDATE ON public.inspection_rounds
  FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

-- RLS
ALTER TABLE public.inspection_rounds ENABLE ROW LEVEL SECURITY;

-- 모든 인증 사용자 조회 가능
CREATE POLICY "rounds_select" ON public.inspection_rounds
  FOR SELECT TO authenticated
  USING (true);

-- 관리자 그룹만 생성 가능
CREATE POLICY "rounds_insert" ON public.inspection_rounds
  FOR INSERT TO authenticated
  WITH CHECK (public.is_admin_group());

-- 관리자 그룹만 수정 가능
CREATE POLICY "rounds_update" ON public.inspection_rounds
  FOR UPDATE TO authenticated
  USING (public.is_admin_group());

-- 관리자만 삭제 가능
CREATE POLICY "rounds_delete" ON public.inspection_rounds
  FOR DELETE TO authenticated
  USING (public.is_admin());

-- 라운드 시작 RPC (draft → active)
CREATE OR REPLACE FUNCTION public.start_inspection_round(p_round_id bigint)
RETURNS public.inspection_rounds
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_row public.inspection_rounds;
  v_user_id bigint;
BEGIN
  IF NOT public.is_admin_group() THEN
    RAISE EXCEPTION 'forbidden: admin group only';
  END IF;

  -- 이미 active인 라운드가 있으면 차단
  IF EXISTS (SELECT 1 FROM public.inspection_rounds WHERE status = 'active') THEN
    RAISE EXCEPTION 'already_active: 이미 진행 중인 실사가 있습니다. 먼저 종료해주세요.';
  END IF;

  SELECT id INTO v_user_id FROM public.users WHERE auth_uid = auth.uid();

  UPDATE public.inspection_rounds
  SET status = 'active',
      started_by = v_user_id,
      started_at = now(),
      updated_at = now()
  WHERE id = p_round_id AND status = 'draft'
  RETURNING * INTO v_row;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'not_found: 라운드를 찾을 수 없거나 이미 시작된 상태입니다.';
  END IF;

  RETURN v_row;
END;
$$;

-- 라운드 종료 RPC (active → closed)
CREATE OR REPLACE FUNCTION public.close_inspection_round(p_round_id bigint)
RETURNS public.inspection_rounds
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_row public.inspection_rounds;
  v_user_id bigint;
BEGIN
  IF NOT public.is_admin_group() THEN
    RAISE EXCEPTION 'forbidden: admin group only';
  END IF;

  SELECT id INTO v_user_id FROM public.users WHERE auth_uid = auth.uid();

  UPDATE public.inspection_rounds
  SET status = 'closed',
      closed_by = v_user_id,
      closed_at = now(),
      updated_at = now()
  WHERE id = p_round_id AND status = 'active'
  RETURNING * INTO v_row;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'not_found: 진행 중인 라운드를 찾을 수 없습니다.';
  END IF;

  RETURN v_row;
END;
$$;

GRANT EXECUTE ON FUNCTION public.start_inspection_round(bigint) TO authenticated;
GRANT EXECUTE ON FUNCTION public.close_inspection_round(bigint) TO authenticated;

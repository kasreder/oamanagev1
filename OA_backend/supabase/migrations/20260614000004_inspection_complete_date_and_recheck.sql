-- =============================================================================
-- 실사: 완료 시점 inspection_date + 재실사 요청 알림
--
-- 1) inspection_date DEFAULT 제거 — 더미/회차자동생성 시 공란이 됨
-- 2) 완료 5필드(건물/층/위치/사진/사인)가 모두 채워지는 UPDATE에서
--    inspection_date = now() 자동 설정 (이미 있으면 유지)
-- 3) 기존 미완료 행 inspection_date NULL 백필
-- 4) notifications.type에 'recheck_request' 허용
-- 5) request_inspection_recheck(p_inspection_id) RPC:
--    - 잠금 풀기(locked=false)
--    - 마스터 관리자 전원에게 notification INSERT
-- =============================================================================

BEGIN;

-- 1) inspection_date DEFAULT 제거
ALTER TABLE public.asset_inspections
  ALTER COLUMN inspection_date DROP DEFAULT;

-- 2) 완료 시점 자동 설정 트리거
CREATE OR REPLACE FUNCTION public.touch_inspection_completed_at()
RETURNS trigger
LANGUAGE plpgsql
AS $$
DECLARE
  is_complete boolean;
BEGIN
  is_complete :=
    NEW.inspection_building IS NOT NULL
    AND NEW.inspection_floor IS NOT NULL
    AND NEW.inspection_position IS NOT NULL
    AND NEW.inspection_photo IS NOT NULL
    AND NEW.signature_image IS NOT NULL;

  IF is_complete AND NEW.inspection_date IS NULL THEN
    NEW.inspection_date := now();
  END IF;

  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_touch_inspection_completed_at ON public.asset_inspections;
CREATE TRIGGER trg_touch_inspection_completed_at
BEFORE INSERT OR UPDATE ON public.asset_inspections
FOR EACH ROW
EXECUTE FUNCTION public.touch_inspection_completed_at();

-- 3) 미완료 행 inspection_date NULL 백필
UPDATE public.asset_inspections
SET inspection_date = NULL
WHERE inspection_date IS NOT NULL
  AND (
    inspection_building IS NULL
    OR inspection_floor IS NULL
    OR inspection_position IS NULL
    OR inspection_photo IS NULL
    OR signature_image IS NULL
  );

-- 4) notifications type CHECK 확장
ALTER TABLE public.notifications
  DROP CONSTRAINT IF EXISTS notifications_type_check;

ALTER TABLE public.notifications
  ADD CONSTRAINT notifications_type_check
  CHECK (type = ANY (ARRAY[
    'os_update'::text,
    'security_alert'::text,
    'general'::text,
    'agent_update'::text,
    'recheck_request'::text
  ]));

-- 5) 재실사 요청 RPC
CREATE OR REPLACE FUNCTION public.request_inspection_recheck(p_inspection_id bigint)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_ins record;
  v_asset_uid text;
BEGIN
  SELECT ai.*, a.asset_uid AS asset_master_uid
    INTO v_ins
  FROM public.asset_inspections ai
  LEFT JOIN public.assets a ON a.id = ai.asset_id
  WHERE ai.id = p_inspection_id;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'inspection % not found', p_inspection_id;
  END IF;

  v_asset_uid := COALESCE(v_ins.asset_master_uid, v_ins.asset_code, p_inspection_id::text);

  -- 잠금 해제 (마스터 관리자가 풀어주는 절차 — 사용자 요구사항대로)
  -- 우선 요청 자체는 잠금 유지 + 관리자가 직접 등록취소(unlock) 하도록 — 알림만 발송.

  -- 마스터 관리자 인원수 ≥ 1이면 알림 1건만 (현재 notifications 스키마는 수신자 컬럼이 없음)
  INSERT INTO public.notifications (asset_uid, type, title, body)
  VALUES (
    v_asset_uid,
    'recheck_request',
    format('재실사 요청: %s', v_asset_uid),
    format('실사 ID %s에 대한 재실사가 요청되었습니다. 관리자가 [등록취소] 버튼으로 잠금을 해제해야 재실사가 가능합니다.', p_inspection_id)
  );
END;
$$;

GRANT EXECUTE ON FUNCTION public.request_inspection_recheck(bigint) TO authenticated;

COMMIT;

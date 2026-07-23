-- =============================================================================
-- 1) assets.admin_company — '롯데카드 외' 선택 시 회사명 입력
-- 2) update_heartbeat RPC 보강 — device_status.mac_address를 자산 마스터로 동기화
-- =============================================================================

BEGIN;

ALTER TABLE public.assets
  ADD COLUMN IF NOT EXISTS admin_company text;

COMMENT ON COLUMN public.assets.admin_company IS
  '담당자 소속이 [롯데카드 외]일 때 입력하는 회사명';

CREATE OR REPLACE FUNCTION public.update_heartbeat(
  p_asset_uid   text,
  p_system_info jsonb DEFAULT NULL
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_mac text;
BEGIN
  -- device_status JSONB에 mac_address가 비어있지 않으면 자산 마스터에 동기화
  v_mac := NULLIF(btrim(p_system_info->>'mac_address'), '');

  UPDATE public.assets
  SET
    last_active_at = now(),
    specifications = CASE
      WHEN p_system_info IS NOT NULL
      THEN jsonb_set(COALESCE(specifications, '{}'), '{device_status}', p_system_info)
      ELSE specifications
    END,
    mac_address = COALESCE(v_mac, mac_address)
  WHERE asset_uid = p_asset_uid;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'asset not found: %', p_asset_uid;
  END IF;
END;
$$;

REVOKE ALL ON FUNCTION public.update_heartbeat(text, jsonb) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.update_heartbeat(text, jsonb) TO authenticated;

COMMIT;

-- OA Manager v1
-- 9.5 is_admin() + reset_inspection() RPC
-- 8.4 get_expiring_assets() RPC

-- 9.5 관리자 여부 확인 함수
CREATE OR REPLACE FUNCTION public.is_admin()
RETURNS boolean
LANGUAGE sql
STABLE
AS $$
  SELECT COALESCE((auth.jwt() ->> 'is_admin')::boolean, false);
$$;

-- 9.5 실사 초기화 RPC (관리자 전용)
CREATE OR REPLACE FUNCTION public.reset_inspection(
  p_inspection_id bigint,
  p_reason text DEFAULT NULL
)
RETURNS public.asset_inspections
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_row public.asset_inspections;
BEGIN
  IF NOT public.is_admin() THEN
    RAISE EXCEPTION 'forbidden: admin only';
  END IF;

  UPDATE public.asset_inspections
  SET
    status = NULL,
    memo = p_reason,
    inspection_photo = NULL,
    signature_image = NULL,
    synced = false,
    updated_at = now()
  WHERE id = p_inspection_id
  RETURNING * INTO v_row;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'inspection not found: %', p_inspection_id;
  END IF;

  RETURN v_row;
END;
$$;

REVOKE ALL ON FUNCTION public.reset_inspection(bigint, text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.reset_inspection(bigint, text) TO authenticated;

-- 8.4 만료 임박 자산 목록 조회
CREATE OR REPLACE FUNCTION public.get_expiring_assets()
RETURNS TABLE (
  id bigint,
  asset_uid text,
  name text,
  supply_type text,
  supply_end_date timestamptz,
  d_day int
) AS $$
BEGIN
  RETURN QUERY
  SELECT
    a.id, a.asset_uid, a.name, a.supply_type, a.supply_end_date,
    (a.supply_end_date::date - CURRENT_DATE)::int AS d_day
  FROM public.assets a
  WHERE a.supply_type IN ('렌탈', '대여')
    AND a.supply_end_date IS NOT NULL
    AND a.supply_end_date <= CURRENT_DATE + INTERVAL '7 days'
    AND a.supply_end_date >= CURRENT_DATE
  ORDER BY a.supply_end_date ASC;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

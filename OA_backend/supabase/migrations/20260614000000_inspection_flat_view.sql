-- =============================================================================
-- 실사 목록용 평탄 view
-- 자산 컬럼을 join하여 모든 컬럼을 같은 레벨에 노출 → PostgREST에서 자산 컬럼 기준 정렬 가능
-- security_invoker로 underlying RLS 정책을 그대로 적용
-- =============================================================================

CREATE OR REPLACE VIEW public.asset_inspections_with_asset
WITH (security_invoker = true)
AS
SELECT
  ai.id,
  ai.asset_id,
  ai.user_id,
  ai.inspector_name,
  ai.user_team,
  ai.asset_code,
  ai.asset_type,
  ai.asset_info,
  ai.inspection_count,
  ai.inspection_date,
  ai.maintenance_company_staff,
  ai.department_confirm,
  ai.inspection_building,
  ai.inspection_floor,
  ai.inspection_position,
  ai.status,
  ai.memo,
  ai.inspection_photo,
  ai.signature_image,
  ai.round_id,
  ai.locked,
  ai.synced,
  ai.created_at,
  ai.updated_at,
  -- 자산 join 컬럼 (평탄)
  a.asset_uid       AS asset_asset_uid,
  a.name            AS asset_name,
  a.category        AS asset_category,
  a.user_name       AS asset_user_name,
  a.user_employee_id AS asset_user_employee_id,
  a.user_department AS asset_user_department,
  a.owner_name      AS asset_owner_name,
  a.owner_employee_id AS asset_owner_employee_id,
  a.owner_department AS asset_owner_department,
  a.admin_name      AS asset_admin_name,
  a.admin_employee_id AS asset_admin_employee_id,
  a.admin_department AS asset_admin_department,
  a.building        AS asset_building,
  a.floor           AS asset_floor,
  a.vendor          AS asset_vendor,
  a.model_name      AS asset_model_name,
  a.serial_number   AS asset_serial_number,
  a.network         AS asset_network,
  a.normal_comment  AS asset_normal_comment,
  a.oa_comment      AS asset_oa_comment
FROM public.asset_inspections ai
LEFT JOIN public.assets a ON a.id = ai.asset_id;

GRANT SELECT ON public.asset_inspections_with_asset TO authenticated;

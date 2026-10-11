-- =============================================================================
-- 인수증·메뉴 권한 테이블: 보안 실행서 기준 정렬
--
-- 1) receipts / receipt_items / vendors / receipt-* 버킷을 관리자 그룹 전용으로.
--    20260922000000 은 "인증 사용자 전체 읽기/쓰기"로 만들었으나, 라이브 DB 에는
--    2026-10-11 확인 시 이미 아래와 같이 좁혀져 있었다(저장소 미반영). 이 부분은
--    저장소를 라이브와 일치시키는 기록이며 라이브 재적용 결과는 동일하다.
-- 2) 위 테이블과 menu_permissions 에 차단 계정·공용 에이전트 RESTRICTIVE 정책 추가
--    (다른 public 테이블과 동일, 20260816000000 / 20260817000003). 신규 변경.
-- =============================================================================

BEGIN;

-- 1) 관리자 그룹 전용 정책 ----------------------------------------------------
DROP POLICY IF EXISTS vendors_select ON public.vendors;
DROP POLICY IF EXISTS vendors_write  ON public.vendors;
CREATE POLICY vendors_select ON public.vendors
  FOR SELECT TO authenticated USING (public.is_admin_group());
CREATE POLICY vendors_write ON public.vendors
  FOR ALL TO authenticated
  USING (public.is_admin_group()) WITH CHECK (public.is_admin_group());

DROP POLICY IF EXISTS receipts_select ON public.receipts;
DROP POLICY IF EXISTS receipts_insert ON public.receipts;
DROP POLICY IF EXISTS receipts_update ON public.receipts;
DROP POLICY IF EXISTS receipts_delete ON public.receipts;
CREATE POLICY receipts_select ON public.receipts
  FOR SELECT TO authenticated USING (public.is_admin_group());
CREATE POLICY receipts_insert ON public.receipts
  FOR INSERT TO authenticated WITH CHECK (public.is_admin_group());
CREATE POLICY receipts_update ON public.receipts
  FOR UPDATE TO authenticated
  USING (public.is_admin_group()) WITH CHECK (public.is_admin_group());
CREATE POLICY receipts_delete ON public.receipts
  FOR DELETE TO authenticated USING (public.is_admin());

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

DROP POLICY IF EXISTS receipt_signatures_all ON storage.objects;
DROP POLICY IF EXISTS receipt_assets_all     ON storage.objects;
CREATE POLICY receipt_signatures_all ON storage.objects
  FOR ALL TO authenticated
  USING (bucket_id = 'receipt-signatures' AND public.is_admin_group())
  WITH CHECK (bucket_id = 'receipt-signatures' AND public.is_admin_group());
CREATE POLICY receipt_assets_all ON storage.objects
  FOR ALL TO authenticated
  USING (bucket_id = 'receipt-assets' AND public.is_admin_group())
  WITH CHECK (bucket_id = 'receipt-assets' AND public.is_admin_group());

-- 2) RESTRICTIVE 정책 --------------------------------------------------------
DO $$
DECLARE
  v_table text;
BEGIN
  FOREACH v_table IN ARRAY ARRAY['receipts', 'receipt_items', 'vendors', 'menu_permissions']
  LOOP
    EXECUTE format('DROP POLICY IF EXISTS auth_banned_account_block ON public.%I', v_table);
    EXECUTE format(
      'CREATE POLICY auth_banned_account_block ON public.%I AS RESTRICTIVE FOR ALL TO authenticated USING (public.is_current_auth_account_active()) WITH CHECK (public.is_current_auth_account_active())',
      v_table
    );
    EXECUTE format('DROP POLICY IF EXISTS legacy_agent_block ON public.%I', v_table);
    EXECUTE format(
      'CREATE POLICY legacy_agent_block ON public.%I AS RESTRICTIVE FOR ALL TO authenticated USING (NOT public.is_legacy_agent()) WITH CHECK (NOT public.is_legacy_agent())',
      v_table
    );
  END LOOP;
END;
$$;

COMMIT;

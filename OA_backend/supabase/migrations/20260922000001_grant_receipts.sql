-- receipts / receipt_items / vendors 테이블에 authenticated / service_role GRANT
-- (RLS만으로는 통과 안 되고, 테이블 GRANT가 있어야 PostgREST가 접근 가능)

GRANT SELECT, INSERT, UPDATE, DELETE ON public.vendors        TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.receipts       TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.receipt_items  TO authenticated;

GRANT ALL ON public.vendors, public.receipts, public.receipt_items TO service_role;

-- bigserial 시퀀스도 사용 권한
GRANT USAGE, SELECT ON SEQUENCE public.vendors_id_seq       TO authenticated, service_role;
GRANT USAGE, SELECT ON SEQUENCE public.receipts_id_seq      TO authenticated, service_role;
GRANT USAGE, SELECT ON SEQUENCE public.receipt_items_id_seq TO authenticated, service_role;

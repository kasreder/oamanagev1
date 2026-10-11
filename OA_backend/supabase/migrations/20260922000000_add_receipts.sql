-- OA Manager v1
-- 인수증(receipts) 기능
--  - vendors: 거래처 마스터 (로고, 양식 변형)
--  - receipts: 인수증 (거래처 1, 서명 3 — 거래처/헬프데스크/IT기획팀)
--  - receipt_items: 항목 (자산 optional FK — 자산 등록 전/후 양방향 연결)

BEGIN;

-- ── vendors ──────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.vendors (
  id            bigserial PRIMARY KEY,
  name          text NOT NULL,
  logo_path     text,                      -- storage 'receipt-assets' 경로
  template_variant text DEFAULT 'default',  -- 양식 변형 키
  is_active     boolean NOT NULL DEFAULT true,
  display_order int NOT NULL DEFAULT 0,
  created_at    timestamptz NOT NULL DEFAULT now(),
  updated_at    timestamptz NOT NULL DEFAULT now()
);

CREATE UNIQUE INDEX IF NOT EXISTS vendors_name_key ON public.vendors (name);
CREATE INDEX IF NOT EXISTS vendors_active_idx ON public.vendors (is_active, display_order);

-- ── receipts ─────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.receipts (
  id                    bigserial PRIMARY KEY,
  vendor_id             bigint REFERENCES public.vendors(id) ON DELETE RESTRICT,
  issued_at             date NOT NULL DEFAULT CURRENT_DATE,
  receiver_name         text,
  receiver_department   text,
  memo                  text,
  status                text NOT NULL DEFAULT 'draft'
                          CHECK (status IN ('draft','signed','void')),
  -- 3개 서명 이미지 경로 (Storage bucket 'receipt-signatures')
  sign_vendor           text,
  sign_helpdesk         text,
  sign_it_plan          text,
  created_by            bigint REFERENCES public.users(id) ON DELETE SET NULL,
  created_at            timestamptz NOT NULL DEFAULT now(),
  updated_at            timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS receipts_vendor_idx ON public.receipts (vendor_id, issued_at DESC);
CREATE INDEX IF NOT EXISTS receipts_status_idx ON public.receipts (status, issued_at DESC);

-- ── receipt_items ────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.receipt_items (
  id          bigserial PRIMARY KEY,
  receipt_id  bigint NOT NULL REFERENCES public.receipts(id) ON DELETE CASCADE,
  asset_id    bigint REFERENCES public.assets(id) ON DELETE SET NULL,  -- 양방향 연결 (nullable)
  row_no      int NOT NULL DEFAULT 1,
  category    text,          -- 데스크탑/노트북 등
  name        text,          -- 제품명 (OCR 대상)
  sn          text,          -- 시리얼 번호 (OCR 대상)
  qty         int NOT NULL DEFAULT 1 CHECK (qty > 0),
  note        text,
  created_at  timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS receipt_items_receipt_idx ON public.receipt_items (receipt_id, row_no);
CREATE INDEX IF NOT EXISTS receipt_items_asset_idx ON public.receipt_items (asset_id);

-- ── updated_at 트리거 (기존 handle_updated_at 재사용) ────────────────
CREATE TRIGGER trg_vendors_updated_at
  BEFORE UPDATE ON public.vendors
  FOR EACH ROW EXECUTE FUNCTION public.handle_updated_at();

CREATE TRIGGER trg_receipts_updated_at
  BEFORE UPDATE ON public.receipts
  FOR EACH ROW EXECUTE FUNCTION public.handle_updated_at();

-- ── Storage 버킷 ─────────────────────────────────────────────────────
INSERT INTO storage.buckets (id, name, public)
VALUES
  ('receipt-signatures', 'receipt-signatures', false),
  ('receipt-assets',     'receipt-assets',     false)  -- 거래처 로고
ON CONFLICT (id) DO NOTHING;

-- Storage RLS — 로그인 사용자면 모두 접근. 세밀 정책은 앱 레이어에서.
CREATE POLICY "receipt_signatures_all" ON storage.objects
  FOR ALL TO authenticated
  USING (bucket_id = 'receipt-signatures')
  WITH CHECK (bucket_id = 'receipt-signatures');

CREATE POLICY "receipt_assets_all" ON storage.objects
  FOR ALL TO authenticated
  USING (bucket_id = 'receipt-assets')
  WITH CHECK (bucket_id = 'receipt-assets');

-- ── RLS: vendors / receipts / receipt_items ──────────────────────────
ALTER TABLE public.vendors        ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.receipts       ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.receipt_items  ENABLE ROW LEVEL SECURITY;

-- vendors: 모두 읽기, admin_group만 쓰기
CREATE POLICY vendors_select ON public.vendors FOR SELECT TO authenticated USING (true);
CREATE POLICY vendors_write  ON public.vendors FOR ALL    TO authenticated
  USING (public.is_admin_group()) WITH CHECK (public.is_admin_group());

-- receipts: 로그인 사용자 모두 읽기 / 쓰기 (조직 내부 문서. 관리자만 삭제)
CREATE POLICY receipts_select ON public.receipts FOR SELECT TO authenticated USING (true);
CREATE POLICY receipts_insert ON public.receipts FOR INSERT TO authenticated WITH CHECK (true);
CREATE POLICY receipts_update ON public.receipts FOR UPDATE TO authenticated USING (true) WITH CHECK (true);
CREATE POLICY receipts_delete ON public.receipts FOR DELETE TO authenticated USING (public.is_admin_group());

-- receipt_items: receipts와 동일 정책
CREATE POLICY receipt_items_select ON public.receipt_items FOR SELECT TO authenticated USING (true);
CREATE POLICY receipt_items_insert ON public.receipt_items FOR INSERT TO authenticated WITH CHECK (true);
CREATE POLICY receipt_items_update ON public.receipt_items FOR UPDATE TO authenticated USING (true) WITH CHECK (true);
CREATE POLICY receipt_items_delete ON public.receipt_items FOR DELETE TO authenticated USING (true);

COMMIT;

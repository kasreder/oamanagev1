-- 항목 금액(합계, 원 단위) — 씨토크 등 금액 표기 양식용. 비우면 인쇄 시 공란.
ALTER TABLE public.receipt_items
  ADD COLUMN IF NOT EXISTS amount bigint;

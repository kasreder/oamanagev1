-- 발송담당자 추가 (발송업체 연락처는 UI에서 제거 — 컬럼은 데이터 보존 위해 유지)
ALTER TABLE public.receipts
  ADD COLUMN IF NOT EXISTS sender_manager text;

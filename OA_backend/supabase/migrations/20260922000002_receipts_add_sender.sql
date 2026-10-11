-- 인수증 기본정보에 발송업체 3필드 추가
ALTER TABLE public.receipts
  ADD COLUMN IF NOT EXISTS sender_company    text,
  ADD COLUMN IF NOT EXISTS sender_department text,
  ADD COLUMN IF NOT EXISTS sender_contact    text;

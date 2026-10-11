-- 인수증: 인수업체 + "인수자와 동일" 체크(헬프데스크/IT기획팀 중 하나) 저장
ALTER TABLE public.receipts
  ADD COLUMN IF NOT EXISTS receiver_company text,
  ADD COLUMN IF NOT EXISTS receiver_same_as text
    CHECK (receiver_same_as IN ('helpdesk','it_plan'));

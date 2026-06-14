-- assets.admin_affiliation 추가 (담당자 소속 — 롯데카드 / 롯데카드 외)
ALTER TABLE public.assets
  ADD COLUMN IF NOT EXISTS admin_affiliation text;

COMMENT ON COLUMN public.assets.admin_affiliation IS
  '담당자 소속 — UI 옵션: 롯데카드 / 롯데카드 외 (자유 입력 허용)';

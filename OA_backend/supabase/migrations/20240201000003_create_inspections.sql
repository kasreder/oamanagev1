-- OA Manager v1
-- 4.5 asset_inspections (실사 기록) 테이블 생성

CREATE TABLE public.asset_inspections (
  id            bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  asset_id      bigint REFERENCES public.assets(id)
    ON DELETE RESTRICT,
  user_id       bigint REFERENCES public.users(id)
    ON DELETE SET NULL,
  inspector_name text,
  user_team     text,
  asset_code    text,
  asset_type    text,
  asset_info    jsonb DEFAULT '{}'::jsonb,
  inspection_count int DEFAULT 1,
  inspection_date  timestamptz DEFAULT now(),
  maintenance_company_staff text,
  department_confirm text,
  inspection_building  text,
  inspection_floor     text,
  inspection_position  text,
  status        text,
  memo          text,
  inspection_photo text,
  signature_image  text,
  synced        boolean DEFAULT true,
  created_at    timestamptz DEFAULT now(),
  updated_at    timestamptz DEFAULT now()
);

-- 인덱스
CREATE INDEX idx_inspections_asset_id ON public.asset_inspections(asset_id);
CREATE INDEX idx_inspections_user_id ON public.asset_inspections(user_id);
CREATE INDEX idx_inspections_asset_code ON public.asset_inspections(asset_code);
CREATE INDEX idx_inspections_date ON public.asset_inspections(inspection_date DESC);
CREATE INDEX idx_inspections_synced ON public.asset_inspections(synced)
  WHERE synced = false;

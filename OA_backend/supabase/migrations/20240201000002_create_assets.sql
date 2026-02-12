-- OA Manager v1
-- 4.3 assets (자산 정보) 테이블 생성

CREATE TABLE public.assets (
  id            bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  asset_uid     text UNIQUE NOT NULL
    CHECK (asset_uid ~ '^(B|R|C|L|S)(DT|NB|MN|PR|TB|SC|IP|NW|SV|WR|SD|SM)[0-9]{5}$'),
  name          text,
  assets_status text DEFAULT '가용'
    CHECK (assets_status IN ('사용', '가용', '이동', '점검필요', '고장')),
  supply_type   text DEFAULT '지급'
    CHECK (supply_type IN ('지급', '렌탈', '대여', '창고(대기)', '창고(점검)')),
  supply_end_date timestamptz,
  category      text NOT NULL
    CHECK (category IN ('데스크탑', '모니터', '노트북', 'IP전화기', '스캐너', '프린터', '태블릿', '테스트폰', '네트워크장비', '서버', '웨어러블', '특수목적장비')),
  serial_number  text,
  model_name     text,
  vendor         text,
  network        text,
  physical_check_date timestamptz,
  confirmation_date   timestamptz,
  normal_comment text,
  oa_comment     text,
  mac_address    text,
  building1      text,
  building       text,
  floor          text,
  owner_name     text,
  owner_department text,
  user_name      text,
  user_department text,
  admin_name     text,
  admin_department text,
  location_drawing_id bigint REFERENCES public.drawings(id)
    ON DELETE SET NULL,
  location_row   int,
  location_col   int,
  location_drawing_file text,
  user_id        bigint REFERENCES public.users(id)
    ON DELETE SET NULL,
  specifications jsonb DEFAULT '{}'::jsonb,
  created_at     timestamptz DEFAULT now(),
  updated_at     timestamptz DEFAULT now()
);

-- 인덱스
CREATE INDEX idx_assets_asset_uid ON public.assets(asset_uid);
CREATE INDEX idx_assets_category ON public.assets(category);
CREATE INDEX idx_assets_status ON public.assets(assets_status);
CREATE INDEX idx_assets_supply_type ON public.assets(supply_type);
CREATE INDEX idx_assets_building ON public.assets(building);
CREATE INDEX idx_assets_user_id ON public.assets(user_id);
CREATE INDEX idx_assets_supply_end_date ON public.assets(supply_end_date)
  WHERE supply_type IN ('렌탈', '대여');
CREATE INDEX idx_assets_drawing ON public.assets(location_drawing_id);
CREATE INDEX idx_assets_specifications ON public.assets
  USING gin(specifications);

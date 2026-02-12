-- OA Manager v1
-- 4.6 drawings (도면 정보) 테이블 생성

CREATE TABLE public.drawings (
  id            bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  building      text NOT NULL,
  floor         text NOT NULL,
  drawing_file  text,
  grid_rows     int DEFAULT 10,
  grid_cols     int DEFAULT 8,
  description   text,
  created_at    timestamptz DEFAULT now(),
  updated_at    timestamptz DEFAULT now(),
  UNIQUE(building, floor)
);
CREATE INDEX idx_drawings_building ON public.drawings(building);
CREATE INDEX idx_drawings_building_floor ON public.drawings(building, floor);

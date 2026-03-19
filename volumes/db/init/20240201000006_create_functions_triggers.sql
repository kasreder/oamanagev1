-- OA Manager v1
-- 9.1~9.4 Database Functions & Triggers

-- 9.1 updated_at 자동 갱신 트리거
CREATE OR REPLACE FUNCTION public.handle_updated_at()
RETURNS trigger AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER set_updated_at BEFORE UPDATE ON public.users
  FOR EACH ROW EXECUTE FUNCTION public.handle_updated_at();

CREATE TRIGGER set_updated_at BEFORE UPDATE ON public.assets
  FOR EACH ROW EXECUTE FUNCTION public.handle_updated_at();

CREATE TRIGGER set_updated_at BEFORE UPDATE ON public.asset_inspections
  FOR EACH ROW EXECUTE FUNCTION public.handle_updated_at();

CREATE TRIGGER set_updated_at BEFORE UPDATE ON public.drawings
  FOR EACH ROW EXECUTE FUNCTION public.handle_updated_at();

-- 9.2 asset_uid 형식 검증/정규화 함수
DROP TRIGGER IF EXISTS auto_asset_uid ON public.assets;
DROP FUNCTION IF EXISTS public.generate_asset_uid();
DROP SEQUENCE IF EXISTS asset_uid_seq;
DROP TRIGGER IF EXISTS validate_asset_uid ON public.assets;

CREATE OR REPLACE FUNCTION public.validate_asset_uid()
RETURNS trigger AS $$
BEGIN
  IF NEW.asset_uid IS NULL OR btrim(NEW.asset_uid) = '' THEN
    RAISE EXCEPTION 'asset_uid is required';
  END IF;

  -- 입력 편차 방지: 공백 제거 + 대문자 표준화
  NEW.asset_uid = upper(btrim(NEW.asset_uid));

  IF NEW.asset_uid !~ '^(B|R|C|L|S)(DT|NB|MN|PR|TB|SC|IP|NW|SV|WR|SD|SM)[0-9]{5}$' THEN
    RAISE EXCEPTION 'invalid asset_uid format: %', NEW.asset_uid
      USING HINT = 'Expected format: [B|R|C|L|S][DT|NB|MN|PR|TB|SC|IP|NW|SV|WR|SD|SM][0-9]{5}';
  END IF;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER validate_asset_uid
  BEFORE INSERT OR UPDATE ON public.assets
  FOR EACH ROW EXECUTE FUNCTION public.validate_asset_uid();

-- 9.3 실사 횟수 자동 증가
CREATE OR REPLACE FUNCTION public.set_inspection_count()
RETURNS trigger AS $$
BEGIN
  NEW.inspection_count = (
    SELECT COALESCE(MAX(inspection_count), 0) + 1
    FROM public.asset_inspections
    WHERE asset_code = NEW.asset_code
  );
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER auto_inspection_count BEFORE INSERT ON public.asset_inspections
  FOR EACH ROW EXECUTE FUNCTION public.set_inspection_count();

-- 9.4 사용자 생성 시 Auth <-> users 동기화
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS trigger AS $$
BEGIN
  INSERT INTO public.users (
    auth_uid,
    employee_id,
    employee_name,
    employment_type,
    organization_hq,
    organization_dept,
    organization_team,
    organization_part,
    organization_etc,
    work_building,
    work_floor,
    auth_provider,
    sns_id
  )
  VALUES (
    NEW.id,
    COALESCE(NEW.raw_user_meta_data->>'employee_id', split_part(NEW.email, '@', 1)),
    COALESCE(NEW.raw_user_meta_data->>'employee_name', ''),
    COALESCE(NEW.raw_user_meta_data->>'employment_type', '정규직'),
    NEW.raw_user_meta_data->>'organization_hq',
    NEW.raw_user_meta_data->>'organization_dept',
    NEW.raw_user_meta_data->>'organization_team',
    NEW.raw_user_meta_data->>'organization_part',
    NEW.raw_user_meta_data->>'organization_etc',
    NEW.raw_user_meta_data->>'work_building',
    NEW.raw_user_meta_data->>'work_floor',
    COALESCE(NEW.raw_user_meta_data->>'auth_provider', 'email'),
    NEW.raw_user_meta_data->>'sns_id'
  );
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();

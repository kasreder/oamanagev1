-- OAManager: Supabase 내부 스키마 초기화
-- DB 볼륨이 비어있을 때 최초 1회 실행

CREATE SCHEMA IF NOT EXISTS _realtime;
GRANT ALL ON SCHEMA _realtime TO supabase_admin;
GRANT ALL ON SCHEMA _realtime TO postgres;

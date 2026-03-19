-- =============================================================================
-- 에이전트 관련 테이블 생성: device_tokens, notifications, agent_settings
-- =============================================================================

-- 4.9 device_tokens (에이전트 FCM 토큰)
CREATE TABLE public.device_tokens (
  id            bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  asset_uid     text UNIQUE NOT NULL
    REFERENCES public.assets(asset_uid) ON DELETE CASCADE,
  fcm_token     text NOT NULL,
  platform      text NOT NULL DEFAULT 'android'
    CHECK (platform IN ('android', 'ios', 'linux', 'windows')),
  updated_at    timestamptz DEFAULT now()
);

CREATE INDEX idx_device_tokens_asset_uid ON public.device_tokens(asset_uid);
CREATE INDEX idx_device_tokens_platform ON public.device_tokens(platform);

-- 4.10 notifications (푸시 알림 이력)
CREATE TABLE public.notifications (
  id            bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  asset_uid     text,
  type          text NOT NULL DEFAULT 'general'
    CHECK (type IN ('os_update', 'security_alert', 'general', 'agent_update')),
  title         text NOT NULL,
  body          text,
  sent_at       timestamptz DEFAULT now(),
  read_at       timestamptz
);

CREATE INDEX idx_notifications_asset_uid ON public.notifications(asset_uid);
CREATE INDEX idx_notifications_type ON public.notifications(type);
CREATE INDEX idx_notifications_sent_at ON public.notifications(sent_at DESC);

-- 4.11 agent_settings (에이전트 설정)
CREATE TABLE public.agent_settings (
  setting_key   text PRIMARY KEY,
  setting_value text NOT NULL,
  updated_at    timestamptz DEFAULT now()
);

INSERT INTO public.agent_settings (setting_key, setting_value)
VALUES
  ('latest_agent_version', '1.0.0'),
  ('min_agent_version', '1.0.0'),
  ('agent_download_url', 'https://example.com/agent/latest.apk');

-- RLS 활성화
ALTER TABLE public.device_tokens ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.notifications ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.agent_settings ENABLE ROW LEVEL SECURITY;

-- updated_at 트리거
CREATE TRIGGER set_updated_at BEFORE UPDATE ON public.device_tokens
  FOR EACH ROW EXECUTE FUNCTION public.handle_updated_at();

CREATE TRIGGER set_updated_at BEFORE UPDATE ON public.agent_settings
  FOR EACH ROW EXECUTE FUNCTION public.handle_updated_at();

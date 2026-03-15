-- =============================================================================
-- 에이전트 관련 RLS 정책
-- =============================================================================

-- 5.6 device_tokens 정책
CREATE POLICY "device_tokens_select" ON public.device_tokens
  FOR SELECT TO authenticated
  USING (true);

CREATE POLICY "device_tokens_insert" ON public.device_tokens
  FOR INSERT TO authenticated
  WITH CHECK (true);

CREATE POLICY "device_tokens_update" ON public.device_tokens
  FOR UPDATE TO authenticated
  USING (true)
  WITH CHECK (true);

CREATE POLICY "device_tokens_delete" ON public.device_tokens
  FOR DELETE TO authenticated
  USING (true);

-- 5.7 notifications 정책
CREATE POLICY "notifications_select" ON public.notifications
  FOR SELECT TO authenticated
  USING (true);

CREATE POLICY "notifications_insert" ON public.notifications
  FOR INSERT TO authenticated
  WITH CHECK (public.is_admin());

CREATE POLICY "notifications_update" ON public.notifications
  FOR UPDATE TO authenticated
  USING (true)
  WITH CHECK (true);

-- 5.8 agent_settings 정책
CREATE POLICY "agent_settings_select" ON public.agent_settings
  FOR SELECT TO anon, authenticated
  USING (true);

CREATE POLICY "agent_settings_update" ON public.agent_settings
  FOR UPDATE TO authenticated
  USING (public.is_admin())
  WITH CHECK (public.is_admin());

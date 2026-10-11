-- =============================================================================
-- OA Manager: GoTrue serializes finite timestamps reliably, whereas `infinity`
-- can cause its user endpoint to fail while evaluating a banned account.
-- Keep the incident-containment bans in place with a practical far-future UTC
-- timestamp; the restrictive database policies remain the primary enforcement.
-- =============================================================================

BEGIN;

WITH affected AS (
  SELECT au.id
  FROM auth.users AS au
  JOIN public.users AS u ON u.auth_uid = au.id
  WHERE lower(u.employee_id) IN (
    'temp01', 'admin01', 'oper01', 'oper02',
    'user01', 'user02', 'user03', 'user04', 'user05'
  )
)
UPDATE auth.users AS au
SET banned_until = '2100-01-01 00:00:00+00'::timestamptz,
    updated_at = now()
FROM affected AS a
WHERE au.id = a.id
  AND au.banned_until = 'infinity'::timestamptz;

COMMIT;

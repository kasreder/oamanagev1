-- Legacy account lifecycle RPCs were superseded by the random-password,
-- master-admin-only secure variants.  Remove the old endpoints completely so
-- they cannot be accidentally re-granted in a future deployment.

BEGIN;

DROP FUNCTION IF EXISTS public.admin_reset_user_password(text);
DROP FUNCTION IF EXISTS public.admin_create_user(text, text, text, text, text);

COMMIT;

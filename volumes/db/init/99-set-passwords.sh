#!/usr/bin/env bash
# Assign distinct self-hosted Supabase service-login passwords on a freshly
# initialized OA database volume.
#
# This file is intentionally an init hook only. Existing volumes need the
# controlled live transition documented with the security remediation; merely
# mounting this script does not rotate their already-created roles.
set -Eeuo pipefail

: "${POSTGRES_PASSWORD:?POSTGRES_PASSWORD must be configured}"
: "${SUPABASE_ADMIN_PASSWORD:?SUPABASE_ADMIN_PASSWORD must be configured}"
: "${SUPABASE_AUTH_ADMIN_PASSWORD:?SUPABASE_AUTH_ADMIN_PASSWORD must be configured}"
: "${AUTHENTICATOR_PASSWORD:?AUTHENTICATOR_PASSWORD must be configured}"
: "${SUPABASE_STORAGE_ADMIN_PASSWORD:?SUPABASE_STORAGE_ADMIN_PASSWORD must be configured}"

# The image's migrate.sh has created supabase_admin with POSTGRES_PASSWORD by
# this point. Use TCP/SCRAM so the hook also rotates that role safely.
export PGPASSWORD="$POSTGRES_PASSWORD"
psql -v ON_ERROR_STOP=1 \
  -v postgres_password="$POSTGRES_PASSWORD" \
  -v supabase_admin_password="$SUPABASE_ADMIN_PASSWORD" \
  -v auth_admin_password="$SUPABASE_AUTH_ADMIN_PASSWORD" \
  -v authenticator_password="$AUTHENTICATOR_PASSWORD" \
  -v storage_admin_password="$SUPABASE_STORAGE_ADMIN_PASSWORD" \
  --host 127.0.0.1 --username supabase_admin --dbname postgres <<-'EOSQL'
  BEGIN;
  SET password_encryption = 'scram-sha-256';

  SELECT format('ALTER ROLE %I PASSWORD %L', role_name, role_password)
    FROM (VALUES
      ('postgres', :'postgres_password'),
      ('supabase_admin', :'supabase_admin_password'),
      ('supabase_auth_admin', :'auth_admin_password'),
      ('authenticator', :'authenticator_password'),
      ('supabase_storage_admin', :'storage_admin_password')
    ) AS roles(role_name, role_password)
  \gexec

  ALTER ROLE supabase_functions_admin NOLOGIN;
  ALTER ROLE supabase_replication_admin NOLOGIN;
  ALTER ROLE supabase_read_only_user NOLOGIN;
  COMMIT;
EOSQL

unset PGPASSWORD

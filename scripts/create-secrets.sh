#!/bin/bash
set -euo pipefail
DB_USER="${DB_USER:-appuser}"
DB_PASSWORD="${DB_PASSWORD:-$(openssl rand -base64 24)}"
API_KEY="${API_KEY:-$(openssl rand -hex 32)}"
docker secret rm db_user db_password db_connection_string api_key 2>/dev/null || true
echo "$DB_USER"        | docker secret create db_user -
echo "$DB_PASSWORD"    | docker secret create db_password -
echo "postgresql://${DB_USER}:${DB_PASSWORD}@postgres:5432/appdb" | docker secret create db_connection_string -
echo "$API_KEY"        | docker secret create api_key -
echo "Done. Password: $DB_PASSWORD"
#!/usr/bin/env bash
set -euo pipefail

PORT="${PORT:-8080}"
HOST="${RAILWAY_PUBLIC_DOMAIN:-localhost}"
ROOT_PASSWORD="${GITLAB_ROOT_PASSWORD:-}"

omnibus="external_url 'http://${HOST}'; nginx['listen_port']=${PORT}; nginx['listen_https']=false; puma['worker_processes']=0; sidekiq['max_concurrency']=10;"

if [ -n "$ROOT_PASSWORD" ]; then
  omnibus="${omnibus} gitlab_rails['initial_root_password']='${ROOT_PASSWORD}';"
fi

export GITLAB_OMNIBUS_CONFIG="$omnibus"

exec /assets/wrapper

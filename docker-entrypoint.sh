#!/usr/bin/env bash
set -euo pipefail

PORT="${PORT:-8080}"
HOST="${RAILWAY_PUBLIC_DOMAIN:-localhost}"

export GITLAB_OMNIBUS_CONFIG="external_url 'http://${HOST}'; nginx['listen_port']=${PORT}; nginx['listen_https']=false; puma['worker_processes']=0; sidekiq['max_concurrency']=10;"

exec /assets/wrapper

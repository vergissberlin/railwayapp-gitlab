#!/usr/bin/env bash
set -euo pipefail

PORT="${PORT:-8080}"
ROOT_PASSWORD="${GITLAB_ROOT_PASSWORD:-}"

# Railway's public domain is only ever reached over HTTPS (TLS terminated at the edge, then
# proxied to this container's $PORT over plain HTTP). external_url must reflect what the
# browser actually sees - scheme and host, no port - otherwise GitLab derives its allowed-host
# check from external_url's host:port and rejects every real request as an unrecognized host.
if [ -n "${RAILWAY_PUBLIC_DOMAIN:-}" ]; then
  HOST="$RAILWAY_PUBLIC_DOMAIN"
  SCHEME="https"
else
  HOST="${RAILWAY_PRIVATE_DOMAIN:-localhost}"
  SCHEME="http"
fi

omnibus="external_url '${SCHEME}://${HOST}'; nginx['listen_port']=${PORT}; nginx['listen_https']=false; nginx['listen_addresses']=['0.0.0.0','[::]']; gitlab_rails['allowed_hosts']=['${HOST}','healthcheck.railway.app','localhost','localhost:8080','127.0.0.1','127.0.0.1:8081']; gitlab_workhorse['listen_network']='tcp'; gitlab_workhorse['listen_addr']='0.0.0.0:8181'; puma['worker_processes']=0; puma['listen']='127.0.0.1'; puma['port']=8081; sidekiq['max_concurrency']=10;"

if [ -n "$ROOT_PASSWORD" ]; then
  omnibus="${omnibus} gitlab_rails['initial_root_password']='${ROOT_PASSWORD}';"
fi

export GITLAB_OMNIBUS_CONFIG="$omnibus"

exec /assets/init-container

#!/usr/bin/env bash
# Pre-flight checks before GitLab touches an existing /var/opt/gitlab volume.
# Exits non-zero (and changes nothing) when an update would skip a GitLab
# required upgrade stop, downgrade GitLab, or start while background
# migrations of the previous version are still running.
# Set GITLAB_SKIP_UPGRADE_GUARD=true to bypass (at your own risk).
set -euo pipefail

DATA=/var/opt/gitlab
VERSION_FILE="$DATA/gitlab-rails/VERSION"
# https://docs.gitlab.com/update/upgrade_paths/
REQUIRED_STOPS="${GITLAB_REQUIRED_STOPS:-17.3 17.5 17.8 17.11 18.2 18.5 18.8 18.11 19.2 19.5 19.8 19.11}"

log() { echo "[railway-upgrade-guard] $*" >&2; }
num() { local IFS=.; set -- $1; echo $(( ${1:-0} * 1000 + ${2:-0} )); }

[ "${GITLAB_SKIP_UPGRADE_GUARD:-false}" = "true" ] && { log "GITLAB_SKIP_UPGRADE_GUARD=true - skipping checks."; exit 0; }
[ -s "$VERSION_FILE" ] || exit 0   # fresh volume

old=$(tr -d '[:space:]' < "$VERSION_FILE")
new=$(awk '/^gitlab-(ce|ee|jh)/ {print $NF}' /opt/gitlab/version-manifest.txt)
old_n=$(num "$old"); new_n=$(num "$new")

fail() {
  log "ERROR: $*"
  log "ERROR: nothing was changed on the volume. See README.md, 'Upgrading GitLab'."
  exit 1
}

if [ "$old_n" -gt "$new_n" ]; then
  fail "this volume was last used by GitLab $old, this image is GitLab $new. Downgrades are not supported; restore a backup or deploy GitLab $old or newer."
fi
[ "$old_n" -eq "$new_n" ] && exit 0   # patch update or restart

prev_stop=0; prev_stop_v=""
for s in $REQUIRED_STOPS; do
  if [ "$(num "$s")" -lt "$new_n" ] && [ "$(num "$s")" -gt "$prev_stop" ]; then prev_stop=$(num "$s"); prev_stop_v=$s; fi
done
if [ -n "$prev_stop_v" ] && [ "$old_n" -lt "$prev_stop" ]; then
  fail "upgrading GitLab $old -> $new would skip the required upgrade stop $prev_stop_v. Run the latest $prev_stop_v.x first (template branch 'gitlab-$prev_stop_v' if available) and wait until its background migrations have finished."
fi

# The bundled PostgreSQL must be able to open the existing data directory.
pgdata="$DATA/postgresql/data"
if [ -s "$pgdata/PG_VERSION" ]; then
  pgv=$(cat "$pgdata/PG_VERSION")
  pgbin="/opt/gitlab/embedded/postgresql/$pgv/bin"
  if [ ! -x "$pgbin/pg_ctl" ]; then
    fail "the database on this volume is PostgreSQL $pgv, but GitLab $new only ships PostgreSQL $(ls /opt/gitlab/embedded/postgresql | tr '\n' ' '). Run GitLab $old (or the latest 18.11.x) once more so that it upgrades the bundled database (gitlab-ctl pg-upgrade), then update."
  fi

  # All batched background migrations of the previous version must be finished.
  owner=$(stat -c '%u:%g' "$pgdata")
  sock=$(mktemp -d /tmp/guard-pg.XXXXXX)
  # Socket-only, temporary trust rule: the OS users of a previous container do not exist yet.
  echo "local all all trust" > "$sock/hba.conf"
  chown -R "$owner" "$sock"
  rm -f "$pgdata/postmaster.pid"
  log "Checking batched background migrations of GitLab $old..."
  if ! chpst -u ":${owner%%:*}:${owner##*:}" "$pgbin/pg_ctl" -D "$pgdata" -w -t 300 -l "$sock/log" \
      -o "-c listen_addresses='' -c unix_socket_directories=$sock -c config_file=$pgdata/postgresql.conf -c hba_file=$sock/hba.conf" start >/dev/null; then
    cat "$sock/log" >&2 || true
    fail "could not start the existing PostgreSQL $pgv database for the pre-flight check."
  fi
  pending=$(chpst -u ":${owner%%:*}:${owner##*:}" "$pgbin/psql" -h "$sock" -U gitlab-psql -d gitlabhq_production -XAt -c \
    "SELECT count(*) FROM batched_background_migrations WHERE status NOT IN (3, 6)" 2>&1) || pending="query failed: $pending"
  chpst -u ":${owner%%:*}:${owner##*:}" "$pgbin/pg_ctl" -D "$pgdata" -m fast -w stop >/dev/null || true
  rm -rf "$sock"
  case "$pending" in
    0) log "OK: GitLab $old -> $new, no pending background migrations." ;;
    *) fail "GitLab $old still has unfinished batched background migrations ($pending). Roll back to the previous deployment, let them finish (Admin > Monitoring > Background migrations), then update again." ;;
  esac
fi
exit 0

#!/usr/bin/env bash
# Keep /etc/gitlab/gitlab-secrets.json on the persistent volume.
# Railway only persists /var/opt/gitlab, so without this GitLab generates new
# secrets on every deploy and can no longer decrypt CI/CD variables, 2FA
# secrets, runner and access tokens that were stored with the old ones.
#
# /etc/gitlab/gitlab-secrets.json becomes a symlink to the copy on the volume.
# An existing file in /etc/gitlab is copied to the volume once. A file that
# already exists on the volume is never overwritten.
set -euo pipefail

VOL_DIR="${GITLAB_PERSISTENT_SECRETS_DIR:-/var/opt/gitlab/railway-secrets}"
VOL_FILE="$VOL_DIR/gitlab-secrets.json"
ETC_FILE=/etc/gitlab/gitlab-secrets.json

log() { echo "[railway-persist-secrets] $*" >&2; }

mkdir -p /etc/gitlab "$VOL_DIR"
chmod 0700 "$VOL_DIR"

if [ -L "$ETC_FILE" ] && [ "$(readlink "$ETC_FILE")" = "$VOL_FILE" ]; then
  exit 0   # already linked
fi

if [ -f "$ETC_FILE" ] && [ ! -L "$ETC_FILE" ]; then
  if [ ! -e "$VOL_FILE" ]; then
    cp -p "$ETC_FILE" "$VOL_FILE.tmp"
    chmod 0600 "$VOL_FILE.tmp"
    mv "$VOL_FILE.tmp" "$VOL_FILE"
    log "Copied existing $ETC_FILE to the volume ($VOL_FILE)."
  elif ! cmp -s "$ETC_FILE" "$VOL_FILE"; then
    keep="$ETC_FILE.replaced-$(date +%Y%m%d%H%M%S)"
    mv "$ETC_FILE" "$keep"
    log "WARNING: $ETC_FILE differs from the copy on the volume. Using the volume copy; the other file was kept as $keep."
  fi
fi

if [ -e "$VOL_FILE" ]; then
  log "Using GitLab secrets from the volume ($VOL_FILE)."
else
  log "No GitLab secrets yet. GitLab will generate them on the volume ($VOL_FILE)."
fi
rm -f "$ETC_FILE"
ln -s "$VOL_FILE" "$ETC_FILE"

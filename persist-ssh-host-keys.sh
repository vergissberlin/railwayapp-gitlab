#!/usr/bin/env bash
# Keep the SSH host keys (/etc/gitlab/ssh_host_*) on the persistent volume.
# Railway only persists /var/opt/gitlab, so without this every deploy creates
# new host keys and SSH clients warn about a changed host key ("REMOTE HOST
# IDENTIFICATION HAS CHANGED") for git@<your-domain>.
#
# Each /etc/gitlab/ssh_host_<type>_key{,.pub} becomes a symlink to the copy on
# the volume. Existing keys in /etc/gitlab are copied to the volume once. Keys
# that already exist on the volume are never overwritten. Missing keys are
# generated directly on the volume.
set -euo pipefail

VOL_DIR="${GITLAB_PERSISTENT_SSH_DIR:-/var/opt/gitlab/railway-ssh}"
ETC_DIR=/etc/gitlab
TYPES="rsa ecdsa ed25519"

log() { echo "[railway-persist-ssh-host-keys] $*" >&2; }

mkdir -p "$ETC_DIR" "$VOL_DIR"
chmod 0700 "$VOL_DIR"

for t in $TYPES; do
  name="ssh_host_${t}_key"
  vol="$VOL_DIR/$name"
  etc="$ETC_DIR/$name"

  if [ -L "$etc" ] && [ "$(readlink "$etc")" = "$vol" ] && [ -s "$vol" ] \
     && [ -L "$etc.pub" ] && [ "$(readlink "$etc.pub")" = "$vol.pub" ] && [ -s "$vol.pub" ]; then
    continue   # already linked
  fi

  if [ ! -s "$vol" ]; then
    if [ -f "$etc" ] && [ ! -L "$etc" ]; then
      # Adopt the key this container already has, once.
      cp -p "$etc" "$vol.tmp"
      chmod 0600 "$vol.tmp"
      mv "$vol.tmp" "$vol"
      rm -f "$vol.pub"
      log "Copied existing $etc to the volume ($vol)."
    else
      rm -f "$vol" "$vol.pub" "$vol.tmp" "$vol.tmp.pub"
      ssh-keygen -q -t "$t" -N '' -C "root@gitlab" -f "$vol.tmp" >/dev/null
      mv "$vol.tmp.pub" "$vol.pub"
      mv "$vol.tmp" "$vol"
      log "Generated a new $t host key on the volume ($vol)."
    fi
  elif [ -f "$etc" ] && [ ! -L "$etc" ] && ! cmp -s "$etc" "$vol"; then
    keep="$etc.replaced-$(date +%Y%m%d%H%M%S)"
    mv "$etc" "$keep"
    [ -f "$etc.pub" ] && [ ! -L "$etc.pub" ] && mv "$etc.pub" "$keep.pub"
    log "WARNING: $etc differs from the key on the volume. Using the volume key; the other one was kept as $keep."
  fi

  # The public key always matches the private key on the volume.
  if [ ! -s "$vol.pub" ] || ! ssh-keygen -y -f "$vol" 2>/dev/null | cmp -s - <(cut -d' ' -f1,2 "$vol.pub"); then
    ssh-keygen -y -f "$vol" > "$vol.pub.tmp"
    mv "$vol.pub.tmp" "$vol.pub"
  fi
  chmod 0600 "$vol"
  chmod 0644 "$vol.pub"

  rm -f "$etc" "$etc.pub"
  ln -s "$vol" "$etc"
  ln -s "$vol.pub" "$etc.pub"
done

log "Using SSH host keys from the volume ($VOL_DIR)."

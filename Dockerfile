FROM gitlab/gitlab-ce:19.2.10-ce.0

COPY --chmod=0755 docker-entrypoint.sh /usr/local/bin/railway-gitlab-entrypoint
COPY --chmod=0755 upgrade-guard.sh /usr/local/bin/railway-gitlab-upgrade-guard
COPY --chmod=0755 persist-secrets.sh /usr/local/bin/railway-gitlab-persist-secrets
COPY --chmod=0755 persist-ssh-host-keys.sh /usr/local/bin/railway-gitlab-persist-ssh-host-keys

CMD ["/usr/local/bin/railway-gitlab-entrypoint"]

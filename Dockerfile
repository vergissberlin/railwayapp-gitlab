FROM gitlab/gitlab-ce:19.2.9-ce.0

COPY --chmod=0755 docker-entrypoint.sh /usr/local/bin/railway-gitlab-entrypoint
COPY --chmod=0755 upgrade-guard.sh /usr/local/bin/railway-gitlab-upgrade-guard

CMD ["/usr/local/bin/railway-gitlab-entrypoint"]

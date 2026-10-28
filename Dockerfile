FROM gitlab/gitlab-ce:18.11.13-ce.0

COPY --chmod=0755 persist-secrets.sh /usr/local/bin/railway-gitlab-persist-secrets
COPY --chmod=0755 docker-entrypoint.sh /usr/local/bin/railway-gitlab-entrypoint

CMD ["/usr/local/bin/railway-gitlab-entrypoint"]

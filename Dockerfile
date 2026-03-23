FROM gitlab/gitlab-ce:18.10.0-ce.0

COPY --chmod=0755 docker-entrypoint.sh /usr/local/bin/railway-gitlab-entrypoint

CMD ["/usr/local/bin/railway-gitlab-entrypoint"]

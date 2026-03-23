FROM gitlab/gitlab-ce:18.10.0-ce.0

COPY docker-entrypoint.sh /usr/local/bin/railway-gitlab-entrypoint
RUN chmod +x /usr/local/bin/railway-gitlab-entrypoint

CMD ["/usr/local/bin/railway-gitlab-entrypoint"]

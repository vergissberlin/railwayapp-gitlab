# GitLab CE

Deploy a self-hosted GitLab CE instance on Railway.

[![Deploy on Railway](https://railway.app/button.svg)](https://railway.com/new)

## Files in this template

- `Dockerfile` uses the official `gitlab/gitlab-ce` image.
- `docker-entrypoint.sh` injects Railway domain and dynamic `$PORT`.
- `railway.toml` configures health checks and restart policy.

## Environment variables

```bash
GITLAB_ROOT_PASSWORD=replace-with-strong-password
```

`RAILWAY_PUBLIC_DOMAIN` and `PORT` are provided by Railway.

## First login

- Username: `root`
- Password: value from `GITLAB_ROOT_PASSWORD`

## Persistent storage

Attach a Railway volume and mount these paths:

- `/var/opt/gitlab`
- `/etc/gitlab`
- `/var/log/gitlab`

## Notes

- GitLab needs significant RAM and CPU. Use a larger Railway plan for production.
- First boot can take several minutes.
- Keep at least one persistent volume attached before storing projects.

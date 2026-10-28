# GitLab CE

> [!IMPORTANT]
> **Requires at least 4 GB RAM (8 GB recommended) and 2 vCPU.** On Railway's Free or Trial plan GitLab is OOM-killed during its first `gitlab-ctl reconfigure` and the deploy fails. Use the **Hobby or Pro plan**. The first boot takes 10–20 minutes before the healthcheck passes. The template already applies GitLab's [memory-constrained settings](https://docs.gitlab.com/omnibus/settings/memory_constrained_envs/) (single Puma process, Sidekiq concurrency 10, Prometheus monitoring off).

![Template Header](./template-header.svg)

Deploy a self-hosted GitLab CE instance on Railway.

[![Deploy on Railway](https://railway.com/button.svg)](https://railway.com/deploy/gitlab-ce?referralCode=2_sIT9&utm_medium=integration&utm_source=template&utm_campaign=generic)

## 🏗️ Architecture

```mermaid
flowchart LR
    Client(["🌐 Client"]) -->|HTTPS| Domain["Railway Public Domain"]
    Domain -->|"$PORT"| Entry["railway-gitlab-entrypoint"]
    Entry --> App["Container\ngitlab/gitlab-ce"]
    App --> Volume[("Volume\n/var/opt/gitlab")]
```

## Files in this template

- `Dockerfile` uses the official `gitlab/gitlab-ce` image.
- `docker-entrypoint.sh` injects Railway domain and dynamic `$PORT`.
- `upgrade-guard.sh` refuses unsafe GitLab upgrades before they touch the volume (see [Upgrading GitLab](#upgrading-gitlab)).
- `railway.toml` configures health checks, restart policy, and required volume mount.

## Environment variables

```bash
GITLAB_ROOT_PASSWORD=replace-with-strong-password
```

`RAILWAY_PUBLIC_DOMAIN` and `PORT` are provided by Railway.

## Public domain setup

Railway does not auto-generate a public domain during template deploy.

After deploying this template:

1. Open the service in Railway.
2. Go to `Settings` -> `Networking` -> `Public Networking`.
3. Click `Generate Domain`.

Once generated, `RAILWAY_PUBLIC_DOMAIN` is available and used by the entrypoint.

## Post-deploy checklist

- [ ] Set a strong `GITLAB_ROOT_PASSWORD`.
- [ ] Generate a public domain in Railway (`Settings` -> `Networking` -> `Public Networking`).
- [ ] Attach a persistent volume and mount:
  - `/var/opt/gitlab`
  - `/etc/gitlab`
  - `/var/log/gitlab`
- [ ] Wait for first boot to complete before first login.

## Railway deploy runbook

Use this order to avoid blocked-host issues on first setup:

1. Deploy once.
2. Generate a public domain in Railway.
3. Deploy again (so `RAILWAY_PUBLIC_DOMAIN` is present at boot time).
4. Verify the application with:
   - `https://<your-domain>/users/sign_in`

## First login

- Username: `root`
- Password: value from `GITLAB_ROOT_PASSWORD`

## Persistent storage

Attach a Railway volume and mount these paths:

- `/var/opt/gitlab`
- `/etc/gitlab`
- `/var/log/gitlab`

`railway.toml` enforces `/var/opt/gitlab` via `requiredMountPath` as the minimum persistent path.

## Upgrading GitLab

GitLab has to be upgraded along its [required upgrade stops](https://docs.gitlab.com/update/upgrade_paths/) (`… 18.11 → 19.2 → 19.5 → 19.8 → 19.11`). Each stop must run until its batched background migrations are finished before you move on. Skipping a stop can leave the database half-migrated.

| Template release | GitLab | Bundled PostgreSQL | Upgrade from |
|---|---|---|---|
| 0.2.x | 18.11.x (required stop) | 16 and 17 (auto `pg-upgrade` to 17) | 18.10 or older 18.x |
| 0.3.x | **19.2.x** (required stop) | 17 only | **18.11.x** only |

The template moves through the stops one release at a time: it does not jump straight to the newest GitLab. Before GitLab touches an existing volume, `upgrade-guard.sh` checks four things. If a check fails, it stops the container with a clear log message **without changing any data**:

- **Required stop skipped.** For example, a volume last used by GitLab 18.10 cannot go to 19.2.
- **Downgrade.** The volume was used by a newer GitLab than the image.
- **Unsupported database.** The bundled database is still PostgreSQL 16, which GitLab 19 no longer ships. GitLab 18.11 upgrades it to 17 automatically on boot.
- **Pending migrations.** Batched background migrations of the previous version are not finished.

### Updating an existing instance (18.11 → 19.2)

1. Make sure your instance is on template release 0.2.x (GitLab 18.11.x). It should have run long enough for **Admin → Monitoring → Background migrations** to show nothing queued, running or failed.
2. Create a backup: `gitlab-backup create` and keep a copy of `/etc/gitlab/gitlab-secrets.json` and `/etc/gitlab/gitlab.rb`. Or snapshot the Railway volume.
3. Update the service to this release and wait for the healthcheck. Upgrade boots can take as long as the first boot (10–20 minutes).
4. If the guard stops the container, use Railway's **Rollback** to return to the previous deployment, fix the reason from the log, and update again.

**Older instances (GitLab 18.10 or earlier):** point the service source to the branch `gitlab-18.11` (Service → Settings → Source → Branch). Let it boot and finish its background migrations, then switch back to `main`.

GitLab does not support downgrades. To go back, restore your backup.

GitLab 19 removes features that were deprecated in 18.x. Check the [GitLab 19 upgrade notes](https://docs.gitlab.com/update/versions/gitlab_19_changes/) before you update. These are the changes most likely to affect this template:

- **PostgreSQL 17 is required.** The bundled PostgreSQL 16 is gone, and the guard checks this.
- **Mattermost is no longer bundled.** If you set `mattermost[...]` or `mattermost_external_url` in `GITLAB_OMNIBUS_CONFIG`, remove them first, or `gitlab-ctl reconfigure` fails.
- **Webhook payload timestamps use ISO 8601.** Receivers that parse the old format need an update.

The next required stop (19.5) will follow in a later template release, after 19.2 has run.

To bypass the guard (not recommended), set `GITLAB_SKIP_UPGRADE_GUARD=true`.

## Notes

- Memory tuning (set in `docker-entrypoint.sh` following GitLab's [memory-constrained environment guide](https://docs.gitlab.com/omnibus/settings/memory_constrained_envs/)): `puma['worker_processes']=0`, `sidekiq['concurrency']=10`, `prometheus_monitoring['enable']=false` and jemalloc `MALLOC_CONF` decay for Rails. Override them via `GITLAB_OMNIBUS_CONFIG` only if you give the service more memory.
- GitLab needs significant RAM and CPU: plan for at least 4 GB RAM (8 GB recommended) and 2 vCPU. The first boot runs `gitlab-ctl reconfigure` and database migrations and can take 10-20 minutes before the healthcheck passes.
- First boot can take several minutes.
- Keep at least one persistent volume attached before storing projects.

## 💬 Support

Questions or feedback? Visit the [template forum on Railway Central Station](https://station.railway.com/templates/git-lab-ce-dbc250b4).

<!-- footer -->
---

[![Airbyte](https://img.shields.io/badge/Airbyte-615EFF?style=for-the-badge&logo=airbyte&logoColor=white)](https://github.com/vergissberlin/railwayapp-airbyte) [![Apache Airflow](https://img.shields.io/badge/Apache%20Airflow-017CEE?style=for-the-badge&logo=apacheairflow&logoColor=white)](https://github.com/vergissberlin/railwayapp-airflow) [![CloudBeaver](https://img.shields.io/badge/CloudBeaver-382923?style=for-the-badge&logo=dbeaver&logoColor=white)](https://github.com/vergissberlin/railwayapp-cloudbeaver-ce) [![CodiMD](https://img.shields.io/badge/CodiMD-0F766E?style=for-the-badge&logo=markdown&logoColor=white)](https://github.com/vergissberlin/railwayapp-codimd) [![Django](https://img.shields.io/badge/Django-092E20?style=for-the-badge&logo=django&logoColor=white)](https://github.com/vergissberlin/railwayapp-django) [![Email Service](https://img.shields.io/badge/Email%20Service-2563EB?style=for-the-badge&logo=maildotru&logoColor=white)](https://github.com/vergissberlin/railwayapp-email) [![FastAPI](https://img.shields.io/badge/FastAPI-009688?style=for-the-badge&logo=fastapi&logoColor=white)](https://github.com/vergissberlin/railwayapp-fastapi) [![Flask](https://img.shields.io/badge/Flask-3fad48?style=for-the-badge&logo=flask&logoColor=white)](https://github.com/vergissberlin/railwayapp-flask) [![Flowise](https://img.shields.io/badge/Flowise-4F46E5?style=for-the-badge&logo=nodedotjs&logoColor=white)](https://github.com/vergissberlin/railwayapp-flowise) [![GitLab CE](https://img.shields.io/badge/GitLab%20CE-FC6D26?style=for-the-badge&logo=gitlab&logoColor=white)](https://github.com/vergissberlin/railwayapp-gitlab) [![Grafana](https://img.shields.io/badge/Grafana-F46800?style=for-the-badge&logo=grafana&logoColor=white)](https://github.com/vergissberlin/railwayapp-grafana) [![Home Assistant](https://img.shields.io/badge/Home%20Assistant-18BCF2?style=for-the-badge&logo=homeassistant&logoColor=white)](https://github.com/vergissberlin/railwayapp-homeassistant) [![InfluxDB](https://img.shields.io/badge/InfluxDB-22ADF6?style=for-the-badge&logo=influxdb&logoColor=white)](https://github.com/vergissberlin/railwayapp-influxdb) [![MJML](https://img.shields.io/badge/MJML-F45E43?style=for-the-badge&logo=mjml&logoColor=white)](https://github.com/vergissberlin/railwayapp-mjml) [![MongoDB](https://img.shields.io/badge/MongoDB-47A248?style=for-the-badge&logo=mongodb&logoColor=white)](https://github.com/vergissberlin/railwayapp-mongodb) [![Mosquitto MQTT](https://img.shields.io/badge/Mosquitto%20MQTT-3C5280?style=for-the-badge&logo=eclipsemosquitto&logoColor=white)](https://github.com/vergissberlin/railwayapp-mqtt) [![MySQL](https://img.shields.io/badge/MySQL-4479A1?style=for-the-badge&logo=mysql&logoColor=white)](https://github.com/vergissberlin/railwayapp-mysql) [![n8n](https://img.shields.io/badge/n8n-EA4B71?style=for-the-badge&logo=n8n&logoColor=white)](https://github.com/vergissberlin/railwayapp-n8n) [![Node.js](https://img.shields.io/badge/Node.js-339933?style=for-the-badge&logo=nodedotjs&logoColor=white)](https://github.com/vergissberlin/railwayapp-nodejs) [![Node-RED](https://img.shields.io/badge/Node-RED-8F0000?style=for-the-badge&logo=nodered&logoColor=white)](https://github.com/vergissberlin/railwayapp-nodered) [![OpenSearch](https://img.shields.io/badge/OpenSearch-005EB8?style=for-the-badge&logo=opensearch&logoColor=white)](https://github.com/vergissberlin/railwayapp-opensearch) [![Open WebUI](https://img.shields.io/badge/Open%20WebUI-D68E42?style=for-the-badge&logo=ollama&logoColor=white)](https://github.com/vergissberlin/railwayapp-openwebui) [![Operately](https://img.shields.io/badge/Operately-3185FF?style=for-the-badge&logo=operately&logoColor=white)](https://github.com/vergissberlin/railwayapp-operately) [![Outerbase Studio](https://img.shields.io/badge/Outerbase%20Studio-000000?style=for-the-badge&logo=outerbase&logoColor=white)](https://github.com/vergissberlin/railwayapp-outerbase-studio) [![PostgreSQL](https://img.shields.io/badge/PostgreSQL-4169E1?style=for-the-badge&logo=postgresql&logoColor=white)](https://github.com/vergissberlin/railwayapp-postgresql) [![Redis](https://img.shields.io/badge/Redis-DC382D?style=for-the-badge&logo=redis&logoColor=white)](https://github.com/vergissberlin/railwayapp-redis) [![TYPO3 CMS](https://img.shields.io/badge/TYPO3%20CMS-FF8700?style=for-the-badge&logo=typo3&logoColor=white)](https://github.com/vergissberlin/railwayapp-typo3)

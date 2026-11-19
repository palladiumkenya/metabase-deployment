# Metabase + Postgres (Docker Compose)

## Quick start

```bash
cp .env.example .env     # edit METABASE_VERSION / credentials
docker compose up -d
```

Metabase: http://localhost:3000 (first boot takes 1–2 minutes while migrations run).

## Pinning the Metabase version

`METABASE_VERSION` in `.env` is the image tag:

```bash
METABASE_VERSION=v0.56.8 docker compose up -d   # one-off
```

To upgrade: change the value, then `docker compose up -d metabase`. Metabase migrates
the app DB on startup and **downgrades are not supported** — snapshot the volume first:

```bash
docker compose exec postgres pg_dump -U metabase -Fc metabase > dumps/backup.dump
```

## Restoring an existing Metabase database

1. Put the dump in `dumps/` — `*.dump`/`*.custom`/`*.tar` (pg_restore) or
   `*.sql`/`*.sql.gz`/`*.sql.bz2` (psql).
2. Make sure the Postgres data volume is empty, since init scripts only run on a
   fresh cluster:
   ```bash
   docker compose down -v
   docker compose up -d
   docker compose logs -f postgres   # watch the [restore] lines
   ```

The restored dump's Metabase version must be **the same as or older than**
`METABASE_VERSION`.

### Restoring without wiping (existing stack)

```bash
docker compose stop metabase
docker compose exec -T postgres pg_restore -U metabase -d metabase \
  --clean --if-exists --no-owner --no-privileges /dumps/your.dump
docker compose start metabase
```

If `dumps/` is empty, Postgres starts clean and Metabase builds a fresh schema.

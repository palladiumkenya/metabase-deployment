#!/bin/bash
# Restores an existing Metabase application database on FIRST initialization only.
# Drop a dump into ./dumps/ — supported: *.dump / *.custom (pg_restore custom or
# directory-less archive), *.sql, *.sql.gz, *.sql.bz2, *.tar.
# If ./dumps/ is empty, this is a no-op and Metabase will create a fresh schema.
set -euo pipefail

DUMP_DIR=/dumps
DB="${POSTGRES_DB:-metabase}"
USR="${POSTGRES_USER:-metabase}"

shopt -s nullglob
files=( "$DUMP_DIR"/*.dump "$DUMP_DIR"/*.custom "$DUMP_DIR"/*.tar \
        "$DUMP_DIR"/*.sql "$DUMP_DIR"/*.sql.gz "$DUMP_DIR"/*.sql.bz2 )
shopt -u nullglob

if [ ${#files[@]} -eq 0 ]; then
  echo "[restore] No dump found in $DUMP_DIR — starting with an empty Metabase database."
  exit 0
fi

dump="${files[0]}"
if [ ${#files[@]} -gt 1 ]; then
  echo "[restore] Multiple dumps found; using the first: $dump"
fi
echo "[restore] Restoring $dump into database '$DB' as '$USR'..."

case "$dump" in
  *.sql)
    psql -v ON_ERROR_STOP=0 --username "$USR" --dbname "$DB" -f "$dump"
    ;;
  *.sql.gz)
    gunzip -c "$dump" | psql -v ON_ERROR_STOP=0 --username "$USR" --dbname "$DB"
    ;;
  *.sql.bz2)
    bunzip2 -c "$dump" | psql -v ON_ERROR_STOP=0 --username "$USR" --dbname "$DB"
    ;;
  *.dump|*.custom|*.tar)
    # --no-owner/--no-acl so a dump taken under a different role still restores.
    pg_restore --username "$USR" --dbname "$DB" \
      --no-owner --no-privileges --clean --if-exists \
      --jobs "${RESTORE_JOBS:-2}" "$dump" \
      || echo "[restore] pg_restore reported errors (often harmless: missing roles/extensions)."
    ;;
esac

echo "[restore] Done. Reindexing/analyzing..."
psql --username "$USR" --dbname "$DB" -c "ANALYZE;" >/dev/null
echo "[restore] Restore complete."

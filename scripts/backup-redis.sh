#!/usr/bin/env bash
set -euo pipefail

APP_DIR=/srv/compose-lab
DEST=/srv/compose-lab-backups
KEEP=7
STAMP="$(date +%F_%H-%M-%S)"

cd "$APP_DIR"

TMP="$(mktemp "$DEST/.redis_XXXXXX.tmp")"
trap 'rm -f "$TMP"' EXIT

# просим Redis записать снимок данных на диск
[[ "$(docker compose exec -T redis redis-cli save)" == "OK" ]] || { echo "Error: redis save failed" >&2; exit 1; }
docker compose cp redis:/data/dump.rdb "$TMP"

# проверяем снимок той же версией Redis, что работает в проекте
REDIS_IMAGE="$(docker compose config --images | grep '^redis:')"
docker run --rm -v "$TMP":/backup.rdb:ro "$REDIS_IMAGE" redis-check-rdb /backup.rdb > /dev/null

chmod 600 "$TMP"
mv "$TMP" "$DEST/redis_$STAMP.rdb"
echo "Backup created: $DEST/redis_$STAMP.rdb"

# ротация: имена содержат дату, поэтому сортировка по имени = по времени
ls -1 "$DEST"/redis_*.rdb | head -n -"$KEEP" | xargs -r rm --

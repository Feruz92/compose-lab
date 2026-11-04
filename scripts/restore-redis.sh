#!/usr/bin/env bash
set -euo pipefail

APP_DIR=/srv/compose-lab
VOLUME=compose-lab_redis-data
TEMP=redis-restore
BACKUP="$(realpath "${1:?usage: restore-redis.sh BACKUP_FILE}")"

[[ -f "$BACKUP" ]] || { echo "Error: $BACKUP not found" >&2; exit 2; }

cd "$APP_DIR"
REDIS_IMAGE="$(docker compose config --images | grep '^redis:')"

# сначала проверяем файл: данные удаляем только при исправном бэкапе
docker run --rm --entrypoint redis-check-rdb -v "$BACKUP":/backup.rdb:ro "$REDIS_IMAGE" /backup.rdb > /dev/null

read -r -p "This deletes current Redis data and restores $BACKUP. Type yes: " answer
[[ "$answer" == "yes" ]] || { echo "Cancelled"; exit 1; }

redis_ready() { docker exec "$TEMP" redis-cli ping 2>/dev/null | grep -q PONG; }
aof_ready() { ! docker exec "$TEMP" redis-cli info persistence | tr -d '\r' | grep -qE '^aof_rewrite_(in_progress|scheduled):1$'; }
wait_for() {
  for _ in {1..30}; do
    "$1" && return 0
    sleep 1
  done
  echo "Error: timeout waiting for $1" >&2
  return 1
}

trap 'docker rm -f "$TEMP" > /dev/null 2>&1 || true' EXIT

docker compose down -v
docker compose up --no-start

# загружаем снимок без AOF, а затем включаем AOF, чтобы Redis записал его в журнал
docker create --name "$TEMP" -v "$VOLUME":/data "$REDIS_IMAGE" redis-server --appendonly no > /dev/null
docker cp "$BACKUP" "$TEMP":/data/dump.rdb
docker start "$TEMP" > /dev/null
wait_for redis_ready
docker exec "$TEMP" redis-cli config set appendonly yes > /dev/null
wait_for aof_ready
docker stop "$TEMP" > /dev/null

docker compose up -d --wait
echo "Restored from $BACKUP"

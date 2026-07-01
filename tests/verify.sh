#!/usr/bin/env bash
#
# Boots the built image and asserts every bundled extension is available,
# installable via CREATE EXTENSION, and that the two preload extensions
# (pg_stat_statements, pg_cron) actually load at startup.
#
# Usage: tests/verify.sh <image> <pg_major>
set -uo pipefail

IMAGE="${1:?image required}"
PG_MAJOR="${2:?pg major required}"
CONTAINER="verify-pg-${PG_MAJOR}-$$"
FAILED=0

EXTENSIONS=(
  vector
  pg_stat_statements
  uuid-ossp
  pgcrypto
  pg_trgm
  postgis
  citext
  unaccent
  hstore
  pg_cron
)

# shellcheck disable=SC2329  # invoked by trap
cleanup() { docker rm -f "$CONTAINER" >/dev/null 2>&1 || true; }
trap cleanup EXIT

fail() { echo "FAIL: $1"; FAILED=1; }

psql() { docker exec "$CONTAINER" psql -U postgres -d postgres -tAX -c "$1" 2>&1; }

docker run -d --name "$CONTAINER" \
  -e POSTGRES_PASSWORD=verify \
  -e POSTGRES_DB=postgres \
  "$IMAGE" >/dev/null

for _ in $(seq 1 60); do
  docker exec "$CONTAINER" pg_isready -U postgres -d postgres >/dev/null 2>&1 && break
  sleep 1
done
if ! docker exec "$CONTAINER" pg_isready -U postgres -d postgres >/dev/null 2>&1; then
  echo "FAIL: PostgreSQL never became ready"
  docker logs "$CONTAINER" 2>&1 | tail -40
  exit 1
fi
sleep 2

echo "===== PG ${PG_MAJOR}: $(psql 'SHOW server_version;') ====="

echo "----- shared_preload_libraries -----"
spl="$(psql 'SHOW shared_preload_libraries;')"
echo "$spl"
if [[ "$spl" == *pg_stat_statements* && "$spl" == *pg_cron* ]]; then
  echo "PASS: preload libraries set"
else
  fail "shared_preload_libraries missing pg_stat_statements and/or pg_cron"
fi

echo "----- pg_available_extensions -----"
for ext in "${EXTENSIONS[@]}"; do
  if [[ "$(psql "SELECT 1 FROM pg_available_extensions WHERE name = '$ext' LIMIT 1;")" == "1" ]]; then
    echo "AVAILABLE: $ext"
  else
    fail "$ext not in pg_available_extensions"
  fi
done

echo "----- CREATE EXTENSION IF NOT EXISTS -----"
for ext in "${EXTENSIONS[@]}"; do
  result="$(psql "CREATE EXTENSION IF NOT EXISTS \"$ext\";")"
  if [[ "$result" == "CREATE EXTENSION" || -z "$result" ]]; then
    echo "CREATED: $ext"
  else
    fail "CREATE EXTENSION $ext -> $result"
  fi
done

echo "----- pg_stat_statements loaded -----"
if [[ "$(psql 'SELECT count(*) >= 0 FROM pg_stat_statements;')" == "t" ]]; then
  echo "PASS: pg_stat_statements view queryable"
else
  fail "pg_stat_statements view not queryable"
fi

echo "----- pg_cron loaded -----"
jobid="$(psql "SELECT cron.schedule('verify-job','* * * * *','SELECT 1');")"
if [[ "$jobid" =~ ^[0-9]+$ ]]; then
  echo "PASS: pg_cron.schedule returned job $jobid"
  psql "SELECT cron.unschedule('verify-job');" >/dev/null
else
  fail "pg_cron.schedule -> $jobid"
fi

echo "----- pgvector usable -----"
distance="$(psql "SELECT '[1,2,3]'::vector <-> '[3,2,1]'::vector;")"
if [[ -n "$distance" && "$distance" != *ERROR* ]]; then
  echo "PASS: vector distance = $distance"
else
  fail "vector operation -> $distance"
fi

echo "----- postgis usable -----"
echo "postgis_version: $(psql 'SELECT postgis_version();')"

echo
if [[ "$FAILED" == "0" ]]; then
  echo "########## PG ${PG_MAJOR}: ALL CHECKS PASSED ##########"
else
  echo "########## PG ${PG_MAJOR}: CHECKS FAILED ##########"
fi
exit "$FAILED"

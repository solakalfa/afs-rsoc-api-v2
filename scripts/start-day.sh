#!/usr/bin/env bash
set -euo pipefail

SERVICE_PREFIX="afs-rsoc-api"
PROJECT="afs-rsoc-api-v2"
REGION="us-central1"

while getopts "p:" opt; do
  case $opt in
    p) SERVICE_PREFIX="$OPTARG" ;;
  esac
done

echo "== RSOC Start Day =="
echo "Project: $PROJECT, Region: $REGION, Service: $SERVICE_PREFIX"

# 1. Git sync
echo "[1/6] Git sync"
git fetch origin
git checkout master
git pull --ff-only

# 2. Load environment variables
echo "[2/6] Exporting secrets"
if [ -f ".env.local" ]; then
  export $(grep -v '^#' .env.local | xargs)
elif [ -f ".env" ]; then
  export $(grep -v '^#' .env | xargs)
fi

if [ -z "${DATABASE_URL:-}" ] || [ -z "${RSOC_API_TOKEN:-}" ]; then
  echo "❌ Missing DATABASE_URL or RSOC_API_TOKEN"
  exit 1
fi

# 3. Check DB connectivity
echo "[3/6] Checking DB"
if ! pg_isready -d "$DATABASE_URL"; then
  echo "❌ Database not reachable"
  exit 1
fi

# 4. Run migrations
echo "[4/6] Running migrations"
for f in sql/migrations/*.sql; do
  [ -e "$f" ] || continue
  echo "Applying $f"
  psql "$DATABASE_URL" -f "$f" >/dev/null
done

# 5. Start local server in background
echo "[5/6] Starting server (background)"
npm install >/dev/null
(node src/server.js &) 2>/dev/null || true
sleep 2

# 6. Smoke tests
echo "[6/6] Smoke tests"
fail=0

health=$(curl -s -o /dev/null -w "%{http_code}" http://127.0.0.1:8080/api/health || echo "000")
if [ "$health" != "200" ]; then
  echo "❌ Health check failed ($health)"
  fail=1
else
  echo "✅ Health check OK"
fi

unauth=$(curl -s -o /dev/null -w "%{http_code}" http://127.0.0.1:8080/api/convert || echo "000")
if [ "$unauth" != "401" ]; then
  echo "❌ Auth check failed ($unauth)"
  fail=1
else
  echo "✅ Auth check OK"
fi

conv=$(curl -s -o /dev/null -w "%{http_code}" -H "Authorization: Bearer $RSOC_API_TOKEN" -H "Content-Type: application/json" -d '{"click_id":"test123","value":1,"currency":"USD"}' http://127.0.0.1:8080/api/convert || echo "000")
if [ "$conv" != "200" ] && [ "$conv" != "201" ]; then
  echo "❌ Conversion flow failed ($conv)"
  fail=1
else
  echo "✅ Conversion flow OK ($conv)"
fi

if [ $fail -eq 0 ]; then
  echo "== ✅ All checks passed =="
else
  echo "== ❌ Some checks failed =="
  exit 1
fi

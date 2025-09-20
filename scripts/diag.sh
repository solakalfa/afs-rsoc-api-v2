#!/usr/bin/env bash
set -euo pipefail

SERVICE="afs-rsoc-api-stg"
REGION="us-central1"
BASE="https://afs-rsoc-api-stg-667309300722.us-central1.run.app"

echo "== Service summary =="
gcloud run services describe "$SERVICE" --region "$REGION" --format='value(status.latestReadyRevisionName)'
gcloud run services describe "$SERVICE" --region "$REGION" --format='get(spec.template.metadata.annotations)' | tr ';' '\n' | sed 's/,/\n/g' | sed 's/{\|}\|map\[\|\]//g' | sed 's/  */ /g' | grep -Ei 'cloudsql|secret|revision'

echo "== Health =="
curl -s "$BASE/api/health" || true
echo

echo "== Quick events test =="
now=$(date -u +%Y-%m-%dT%H:%M:%SZ)
curl -s -X POST -H "Content-Type: application/json" \  -d '{"type":"pageview","click_id":"diag-test","timestamp":"'"$now"'"}' \  "$BASE/api/events" || true
echo
curl -s "$BASE/api/events?limit=3" || true
echo

echo "== Last 50 log lines =="
gcloud run services logs read "$SERVICE" --region "$REGION" --limit=50 --format='value(textPayload)' || true

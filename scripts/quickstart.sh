#!/usr/bin/env bash
set -euo pipefail

PROJECT_ID="afs-rsoc-api-v2"
REGION="us-central1"
STG_SVC="afs-rsoc-api-stg"
PRD_SVC="afs-rsoc-api"

STG_TOKEN_SECRET="RSOC_API_TOKEN_STG"
STG_DB_SECRET="DATABASE_URL_STG"
PRD_TOKEN_SECRET="RSOC_API_TOKEN"
PRD_DB_SECRET="DATABASE_URL"

WITH_DB=0
[[ "${1:-}" == "--with-db" ]] && WITH_DB=1

gcloud config set project "$PROJECT_ID" >/dev/null
PROJECT_NUMBER=$(gcloud projects describe "$PROJECT_ID" --format='value(projectNumber)')
RUNTIME_SA="${PROJECT_NUMBER}-compute@developer.gserviceaccount.com"

git pull --rebase || true
npm i --silent || true

for S in "$STG_TOKEN_SECRET" "$PRD_TOKEN_SECRET" "$STG_DB_SECRET" "$PRD_DB_SECRET"; do
  if gcloud secrets describe "$S" >/dev/null 2>&1; then
    gcloud secrets add-iam-policy-binding "$S" \
      --member="serviceAccount:${RUNTIME_SA}" \
      --role="roles/secretmanager.secretAccessor" >/dev/null || true
  fi
done

# תמיד מצמידים AUTH_TOKEN; DB רק אם --with-db ויש סיקרט
SET_ARGS="AUTH_TOKEN=${STG_TOKEN_SECRET}:latest"
if [[ $WITH_DB -eq 1 ]] && gcloud secrets describe "$STG_DB_SECRET" >/dev/null 2>&1; then
  SET_ARGS="${SET_ARGS},DATABASE_URL=${STG_DB_SECRET}:latest"
else
  # אם בטעות היה מוצמד DB בעבר – מורידים אותו כדי שה-health יהיה ירוק
  gcloud run services update "$STG_SVC" --region "$REGION" --remove-secrets DATABASE_URL --quiet >/dev/null 2>&1 || true
fi
gcloud run services update "$STG_SVC" --region "$REGION" --set-secrets "$SET_ARGS" --quiet || true

# PRD: יעדכן רק אם השירות קיים, באותה לוגיקה (ללא DB כברירת מחדל)
if gcloud run services describe "$PRD_SVC" --region "$REGION" >/dev/null 2>&1; then
  PRD_ARGS="AUTH_TOKEN=${PRD_TOKEN_SECRET}:latest"
  if [[ $WITH_DB -eq 1 ]] && gcloud secrets describe "$PRD_DB_SECRET" >/dev/null 2>&1; then
    PRD_ARGS="${PRD_ARGS},DATABASE_URL=${PRD_DB_SECRET}:latest"
  else
    gcloud run services update "$PRD_SVC" --region "$REGION" --remove-secrets DATABASE_URL --quiet >/dev/null 2>&1 || true
  fi
  gcloud run services update "$PRD_SVC" --region "$REGION" --set-secrets "$PRD_ARGS" --quiet || true
fi

STG_URL=$(gcloud run services describe "$STG_SVC" --region "$REGION" --format='value(status.url)')
echo "STG URL: $STG_URL"

TOKEN=$(gcloud secrets versions access latest --secret="$STG_TOKEN_SECRET" 2>/dev/null || echo "stg-token-CHANGE-ME")

set +e
curl -sf "$STG_URL/api/health" >/dev/null && echo "✅ health OK" || echo "❌ health FAILED"
curl -si -H "Authorization: Bearer $TOKEN" -H "Content-Type: application/json" \
  -d '{"utm_source":"fb","source":"facebook","account_id":"1","campaign_id":"2","adset_id":"3","ad_id":"4"}' "$STG_URL/api/tracking" | head -n1
curl -si -H "Authorization: Bearer $TOKEN" -H "Content-Type: application/json" \
  -d '{"click_id":"11111111-1111-1111-1111-111111111111","value":1.23,"currency":"USD"}' "$STG_URL/api/convert" | head -n1
set -e
echo "🎯 Done."

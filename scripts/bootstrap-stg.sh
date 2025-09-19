#!/usr/bin/env bash
# RSOC — Cloud Staging Bootstrap (Cloud Run + Cloud SQL + Secrets + Smoke)
# Usage: bash scripts/bootstrap-stg.sh
set -euo pipefail

# ---------- CONFIG ----------
PROJECT_ID_DEFAULT="afs-rsoc-api-v2"
REGION="us-central1"
SERVICE="afs-rsoc-api-stg"
SQL_INSTANCE="rsoc-pg17-stg"
DB_NAME="rsoc_stg"
DB_USER="rsoc"
# ----------------------------

say() { printf "\n[%s] %s\n" "$(date +%H:%M:%S)" "$*"; }
fail() { printf "\n[ERROR] %s\n" "$*" >&2; exit 1; }

# 1) Project check
CURRENT_PROJECT="$(gcloud config get-value core/project 2>/dev/null || true)"
if [[ -z "${CURRENT_PROJECT}" || "${CURRENT_PROJECT}" == "(unset)" ]]; then
  say "No active project set. Setting to ${PROJECT_ID_DEFAULT}"
  gcloud config set project "${PROJECT_ID_DEFAULT}" >/dev/null
  CURRENT_PROJECT="${PROJECT_ID_DEFAULT}"
fi
if [[ "${CURRENT_PROJECT}" != "${PROJECT_ID_DEFAULT}" ]]; then
  fail "Active project is '${CURRENT_PROJECT}', expected '${PROJECT_ID_DEFAULT}'.
Run: gcloud config set project ${PROJECT_ID_DEFAULT}"
fi
say "Project OK: ${CURRENT_PROJECT}"

# 2) Enable APIs
say "Enabling required APIs ..."
gcloud services enable run.googleapis.com sqladmin.googleapis.com secretmanager.googleapis.com --quiet

# 3) Cloud SQL
say "Ensuring Cloud SQL instance: ${SQL_INSTANCE}"
if gcloud sql instances describe "${SQL_INSTANCE}" --format="value(name)" >/dev/null 2>&1; then
  say "Cloud SQL exists."
else
  say "Creating Cloud SQL Postgres 17 ..."
  gcloud sql instances create "${SQL_INSTANCE}" \
    --database-version=POSTGRES_17 --cpu=1 --memory=3840MiB --region="${REGION}" --quiet
fi

if gcloud sql databases describe "${DB_NAME}" --instance="${SQL_INSTANCE}" --format="value(name)" >/dev/null 2>&1; then
  say "Database '${DB_NAME}' exists."
else
  gcloud sql databases create "${DB_NAME}" --instance="${SQL_INSTANCE}" --quiet
fi

if gcloud sql users list --instance="${SQL_INSTANCE}" --format="value(name)" | grep -qx "${DB_USER}"; then
  say "DB user '${DB_USER}' exists."
else
  DB_PASS="$(openssl rand -base64 24 | tr -d '=+/')"
  gcloud sql users create "${DB_USER}" --instance="${SQL_INSTANCE}" --password="${DB_PASS}" --quiet
fi

INSTANCE_CONN="$(gcloud sql instances describe "${SQL_INSTANCE}" --format='value(connectionName)')"

# 4) Secrets
if gcloud secrets describe RSOC_API_TOKEN_STG >/dev/null 2>&1; then
  API_TOKEN_STG="$(gcloud secrets versions access latest --secret=RSOC_API_TOKEN_STG)"
else
  API_TOKEN_STG="$(openssl rand -hex 24)"
  printf "%s" "${API_TOKEN_STG}" | gcloud secrets create RSOC_API_TOKEN_STG --data-file=- --quiet
fi

if gcloud secrets describe DATABASE_URL_STG >/dev/null 2>&1; then
  say "DATABASE_URL_STG exists."
else
  DB_PASS="$(gcloud sql users describe ${DB_USER} --instance=${SQL_INSTANCE} --format='value(password)')"
  DATABASE_URL="postgres://${DB_USER}:${DB_PASS}@/${DB_NAME}?host=/cloudsql/${INSTANCE_CONN}"
  printf "%s" "${DATABASE_URL}" | gcloud secrets create DATABASE_URL_STG --data-file=- --quiet
fi

# 5) Deploy Cloud Run
say "Deploying Cloud Run service ..."
gcloud run deploy "${SERVICE}" \
  --source . \
  --region "${REGION}" \
  --allow-unauthenticated \
  --add-cloudsql-instances "${INSTANCE_CONN}" \
  --set-secrets "DATABASE_URL=DATABASE_URL_STG:latest,RSOC_API_TOKEN=RSOC_API_TOKEN_STG:latest" \
  --set-env-vars "NODE_ENV=production" \
  --quiet

STG_URL="$(gcloud run services describe "${SERVICE}" --region "${REGION}" --format='value(status.url)')"
say "Cloud Run URL: ${STG_URL}"

# 6) Smoke tests
say "Health check ..."
curl -fsS "${STG_URL}/api/health" || true

say "Convert smoke ..."
curl -fsS -X POST "${STG_URL}/api/convert" \
  -H "Authorization: Bearer ${API_TOKEN_STG}" \
  -H "Content-Type: application/json" \
  -d '{"click_id":"stg-smoke-1","value":1,"currency":"USD"}' || true

say "DONE ✅ — Staging is live"

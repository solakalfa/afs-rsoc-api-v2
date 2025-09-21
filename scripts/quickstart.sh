#!/usr/bin/env bash
set -euo pipefail

# RSOC — Hardened Quickstart (self-healing)

PROJECT="${PROJECT:-afs-rsoc-api-v2}"
REGION="${REGION:-us-central1}"
SERVICE="${SERVICE:-afs-rsoc-api-stg}"
INSTANCE_CONN="${INSTANCE_CONN:-afs-rsoc-api-v2:us-central1:afs-postgres}"
DB_INSTANCE="${DB_INSTANCE:-afs-postgres}"
DB_NAME="${DB_NAME:-rsocdb}"
DB_USER="${DB_USER:-afsuser}"
AUTH_SECRET="${AUTH_SECRET:-RSOC_API_TOKEN_STG}"
DBURL_SECRET="${DBURL_SECRET:-DATABASE_URL_STG}"

log(){ printf "\033[1;36m➡ %s\033[0m\n" "$*"; }
ok(){  printf "\033[1;32m✓ %s\033[0m\n" "$*"; }
warn(){printf "\033[1;33m! %s\033[0m\n" "$*"; }
fail(){ printf "\033[1;31m✗ %s\033[0m\n" "$*"; exit 1; }

need(){ command -v "$1" >/dev/null || fail "Missing dependency: $1"; }

ensure_secret(){
  local name="$1" value="$2"
  if gcloud secrets describe "$name" >/dev/null 2>&1; then
    [ -n "$value" ] && printf "%s" "$value" | gcloud secrets versions add "$name" --data-file=- >/dev/null && ok "Secret updated: $name" || ok "Secret exists: $name"
  else
    [ -n "$value" ] || fail "Secret $name missing and no value supplied"
    printf "%s" "$value" | gcloud secrets create "$name" --data-file=- >/dev/null
    ok "Secret created: $name"
  fi
}

latest_secret_val(){
  gcloud secrets versions access latest --secret="$1" 2>/dev/null || true
}

ensure_db_user(){
  local user="$1" pass="$2"
  gcloud sql users set-password "$user" --instance="$DB_INSTANCE" --password="$pass" >/dev/null \
    && ok "DB user password set ($user)"
}

wire_service(){
  gcloud run services update "$SERVICE" \
    --region "$REGION" \
    --add-cloudsql-instances "$INSTANCE_CONN" \
    --set-secrets=AUTH_TOKEN=${AUTH_SECRET}:latest,DATABASE_URL=${DBURL_SECRET}:latest \
    --update-env-vars=DB_ENABLED=true,RELOAD_TS=$(date +%s) >/dev/null
  ok "Service updated (secrets + Cloud SQL)"
}

health_check(){
  local url; url="$(gcloud run services describe "$SERVICE" --region "$REGION" --format='value(status.url)')"
  [ -n "$url" ] || fail "Service URL not found"
  ok "Service URL: $url"
  local out=""
  for i in {1..15}; do
    out="$(curl -sS "$url/api/health" || true)"
    echo "$out" | grep -q '"db":true' && { ok "Health OK (db:true)"; echo "$out"; return 0; }
    sleep 2
  done
  echo "$out"
  return 1
}

main(){
  need gcloud; need curl
  log "Set project → $PROJECT"
  gcloud config set project "$PROJECT" >/dev/null

  # Ensure AUTH secret exists
  ensure_secret "$AUTH_SECRET" ""

  # Ensure DATABASE_URL secret exists and is valid (points to $DB_NAME via socket)
  local dburl
  dburl="$(latest_secret_val "$DBURL_SECRET")"
  if [[ -z "$dburl" || "$dburl" != *"/$DB_NAME?host=/cloudsql/$INSTANCE_CONN"* ]]; then
    warn "DATABASE_URL missing or mismatched DB/instance → self-healing"
    local pass; pass="$(LC_ALL=C tr -dc 'A-Za-z0-9' </dev/urandom | head -c24)"
    ensure_db_user "$DB_USER" "$pass"
    dburl="postgresql://$DB_USER:$pass@/$DB_NAME?host=/cloudsql/$INSTANCE_CONN&sslmode=disable"
    ensure_secret "$DBURL_SECRET" "$dburl"
  else
    ok "DATABASE_URL secret looks aligned"
  fi

  wire_service

  if ! health_check; then
    warn "db:false after update → printing last errors"
    gcloud logging read \
      'resource.type="cloud_run_revision" resource.labels.service_name="'$SERVICE'" severity>=ERROR' \
      --limit=50

#!/usr/bin/env bash
# scripts/start-day.sh
# RSOC — פתיחת יום זריזה: GCP auth, בחירת פרויקט, STG URL, Health, Smoke, Newman.
# שימוש:
#   ./scripts/start-day.sh [-p <PROJECT_ID>] [-r us-central1] [-u <REPO_URL>] [-d <REPO_DIR>] [-s <SERVICE_PREFIX>]
# דיפולטים: PROJECT_ID=afs-rsoc-api-v2, REGION=us-central1, REPO_URL=https://github.com/solakalfa/afs-rsoc-api-v2.git

set -Eeuo pipefail

# ---- Defaults (aligned to single active project) ----
PROJECT_ID="${RSOC_PROJECT_ID:-afs-rsoc-api-v2}"
REGION="${REGION:-us-central1}"
REPO_URL="${REPO_URL:-https://github.com/solakalfa/afs-rsoc-api-v2.git}"
REPO_DIR="${REPO_DIR:-$HOME/afs-rsoc-api-v2}"
SERVICE_PREFIX="${SERVICE_PREFIX:-afs-rsoc-api}"
SERVICE_NAME_STG="${SERVICE_NAME_STG:-afs-rsoc-api-stg}"

while getopts "p:r:u:d:s:" opt; do
  case $opt in
    p) PROJECT_ID="$OPTARG" ;;
    r) REGION="$OPTARG" ;;
    u) REPO_URL="$OPTARG" ;;
    d) REPO_DIR="$OPTARG" ;;
    s) SERVICE_PREFIX="$OPTARG" ;;
    *) echo "Usage: $0 [-p project] [-r region] [-u repo_url] [-d repo_dir] [-s service_prefix]"; exit 1 ;;
  endswac
done 2>/dev/null || true

log(){ printf "\n== %s ==\n" "$*"; }
have(){ command -v "$1" >/dev/null 2>&1; }

ensure_gcloud_auth(){
  log "בדיקת התחברות ל-gcloud"
  local acct
  acct="$(gcloud auth list --filter=status:ACTIVE --format='value(account)' || true)"
  if [[ -z "$acct" ]]; then
    echo "❌ אין חשבון פעיל. הרץ:  gcloud auth login  ואז  gcloud config set account <YOUR_EMAIL>"
    exit 1
  fi
  echo "מחובר כ-$acct"
}

ensure_project(){
  log "הגדרת פרויקט ואזור (project=$PROJECT_ID, region=$REGION)"
  gcloud config set project "$PROJECT_ID" >/dev/null
  gcloud config set run/region "$REGION" >/dev/null
}

sync_repo(){
  log "משיכת/עדכון ריפו ($REPO_URL → $REPO_DIR)"
  if [[ -d "$REPO_DIR/.git" ]]; then
    (cd "$REPO_DIR" && git pull --ff-only)
  else
    git clone "$REPO_URL" "$REPO_DIR"
  fi
  cd "$REPO_DIR"
}

run_quickstart_if_any(){
  log "Bootstrap/Deploy (אם קיים scripts/quickstart.sh)"
  if [[ -x "scripts/quickstart.sh" ]]; then
    ./scripts/quickstart.sh
  else
    echo "⌁ אין scripts/quickstart.sh — ממשיך."
  fi
}

resolve_stg_url(){
  log "איתור שירות STG וכתובת"
  # מנסה לפי שם סטטי; אם לא קיים — לפי prefix ראשון
  if gcloud run services describe "$SERVICE_NAME_STG" --format='value(status.url)' >/dev/null 2>&1; then
    STG_URL="$(gcloud run services describe "$SERVICE_NAME_STG" --format='value(status.url)')"
    SERVICE="$SERVICE_NAME_STG"
  else
    SERVICE="$(gcloud run services list --format='value(metadata.name)' | grep -E "^${SERVICE_PREFIX}" | head -n1 || true)"
    [[ -z "$SERVICE" ]] && { echo "❌ לא נמצא שירות שמתחיל ב-${SERVICE_PREFIX}"; exit 2; }
    STG_URL="$(gcloud run services describe "$SERVICE" --format='value(status.url)')"
  fi
  if [[ -z "${STG_URL:-}" ]]; then
    echo "❌ STG_URL ריק — בדוק הרשאות ושהשירות פרוס."; exit 3
  fi
  export STG_URL
  echo "שירות: $SERVICE"
  echo "כתובת: $STG_URL"
}

pretty_json(){ if have jq; then jq . || cat; else cat; fi; }

health_and_smoke(){
  log "Health"
  set +e
  echo -n "/api/health:     " ; curl -sS --max-time 10 "$STG_URL/api/health"     | pretty_json || echo "❌"
  echo -n "/api/health-db:  " ; curl -sS --max-time 10 "$STG_URL/api/health-db"  | pretty_json || echo "❌"
  set -e

  log "DB Smoke (אם יש)"
  if [[ -x "scripts/db-smoke.sh" ]]; then
    ./scripts/db-smoke.sh || echo "⚠️ db-smoke נכשל — בדוק קונפיג/גישה ל-DB"
  else
    echo "⌁ אין scripts/db-smoke.sh — מדלג."
  fi
}

run_newman(){
  log "Newman — Auth & Validation (אם יש)"
  if [[ -f "postman/rsoc-auth-validation.json" ]]; then
    have newman || npm i -g newman >/dev/null 2>&1 || true
    if [[ -z "${RSOC_API_TOKEN_STG:-}" ]]; then
      echo "⚠️ RSOC_API_TOKEN_STG לא מוגדר — 401 צפוי. (gcloud secrets versions access… או export)"
    fi
    newman run postman/rsoc-auth-validation.json \
      --env-var baseUrl="$STG_URL" \
      --env-var token="${RSOC_API_TOKEN_STG:-MISSING_TOKEN}" \
      || echo "⚠️ Newman נכשל — בדוק baseUrl/token/שרת."
  else
    echo "⌁ אין postman/rsoc-auth-validation.json — מדלג."
  fi
}

main(){
  ensure_gcloud_auth
  ensure_project
  sync_repo
  run_quickstart_if_any
  resolve_stg_url
  health_and_smoke
  run_newman
  log "מוכן לפיתוח — URL: $STG_URL"
}

main "$@"

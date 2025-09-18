#!/usr/bin/env bash
# scripts/start-day.sh
# RSOC — הפעלה מהירה בבוקר: בחירת פרויקט, משיכת ריפו, Bootstrap, בדיקות Health/Smoke.
# שימוש:
#   ./scripts/start-day.sh -p <PROJECT_ID> [-r us-central1] [-u <REPO_URL>] [-d <REPO_DIR>] [-s <SERVICE_PREFIX>]
# ברירות מחדל: REGION=us-central1, REPO_URL=https://github.com/solakalfa/afs-rsoc.git, REPO_DIR=$HOME/afs-rsoc, SERVICE_PREFIX=afs-rsoc-api

set -Eeuo pipefail

REGION="us-central1"
REPO_URL="https://github.com/solakalfa/afs-rsoc.git"
REPO_DIR="$HOME/afs-rsoc"
SERVICE_PREFIX="afs-rsoc-api"
PROJECT_ID="${RSOC_PROJECT_ID:-}"

while getopts "p:r:u:d:s:" opt; do
  case $opt in
    p) PROJECT_ID="$OPTARG" ;;
    r) REGION="$OPTARG" ;;
    u) REPO_URL="$OPTARG" ;;
    d) REPO_DIR="$OPTARG" ;;
    s) SERVICE_PREFIX="$OPTARG" ;;
    *) echo "Usage: $0 -p <PROJECT_ID> [-r region] [-u repo_url] [-d repo_dir] [-s service_prefix]"; exit 1 ;;
  endac
done 2>/dev/null || true

log(){ printf "\n== %s ==\n" "$*"; }
have(){ command -v "$1" >/dev/null 2>&1; }

choose_project(){
  log "בחירת פרויקט GCP"
  if [[ -n "${PROJECT_ID:-}" ]]; then
    echo "נבחר פרויקט: $PROJECT_ID"
    return
  fi
  echo "אין PROJECT_ID. טוען רשימת פרויקטים..."
  mapfile -t ROWS < <(gcloud projects list --format="value(projectId,name)")
  if [[ "${#ROWS[@]}" -eq 0 ]]; then
    echo "❌ לא נמצאו פרויקטים בחשבון." ; exit 1
  fi
  for i in "${!ROWS[@]}"; do
    PID="${ROWS[$i]%% *}"; NAME="${ROWS[$i]#* }"
    printf "[%d] %s  (%s)\n" "$((i+1))" "$PID" "$NAME"
  done
  read -rp "הקלד מספר לבחירה: " idx
  [[ "$idx" =~ ^[0-9]+$ ]] || { echo "בחירה לא חוקית"; exit 1; }
  PROJECT_ID="${ROWS[$((idx-1))]%% *}"
  echo "נבחר: $PROJECT_ID"
}

pretty_json(){
  if have jq; then jq . || cat
  else cat
  fi
}

main(){
  choose_project

  log "הגדרת קונפיג לאזור ולפרויקט"
  gcloud config set project "$PROJECT_ID" >/dev/null
  gcloud config set run/region "$REGION" >/dev/null
  gcloud auth list

  log "בדיקת הרשאות בסיסיות"
  gcloud run services list --format="table(metadata.name,status.url)" || true

  log "משיכת/עדכון ריפו ($REPO_URL → $REPO_DIR)"
  if [[ -d "$REPO_DIR/.git" ]]; then
    (cd "$REPO_DIR" && git pull --ff-only)
  else
    git clone "$REPO_URL" "$REPO_DIR"
  fi
  cd "$REPO_DIR"

  log "Bootstrap/Deploy (אם קיים scripts/quickstart.sh)"
  if [[ -x "scripts/quickstart.sh" ]]; then
    ./scripts/quickstart.sh
  else
    echo "⚠️ לא נמצא scripts/quickstart.sh — ממשיך לבדיקה."
  fi

  log "איתור שירות Cloud Run"
  SERVICE="$(gcloud run services list --format='value(metadata.name)' | grep -E "^${SERVICE_PREFIX}" | head -n1 || true)"
  if [[ -z "$SERVICE" ]]; then
    echo "❌ לא נמצא שירות שמתחיל ב-${SERVICE_PREFIX}. בדוק את ה־deploy." ; exit 2
  fi
  URL="$(gcloud run services describe "$SERVICE" --format='value(status.url)')"
  echo "שירות: $SERVICE"
  echo "כתובת: $URL"

  log "Health Checks"
  set +e
  echo -n "/api/health:     " ; curl -sS --max-time 10 "$URL/api/health" | pretty_json || echo "❌"
  echo -n "/api/health-db:  " ; curl -sS --max-time 10 "$URL/api/health-db" | pretty_json || echo "❌"
  set -e

  log "בדיקת Secrets קריטיים"
  (gcloud secrets describe RSOC_API_TOKEN_STG >/dev/null && echo "RSOC_API_TOKEN_STG ✅") || echo "RSOC_API_TOKEN_STG ❌"
  (gcloud secrets describe DATABASE_URL_STG   >/dev/null && echo "DATABASE_URL_STG ✅")   || echo "DATABASE_URL_STG ❌"

  log "DB Smoke (אם יש)"
  if [[ -x "scripts/db-smoke.sh" ]]; then
    ./scripts/db-smoke.sh || echo "⚠️ db-smoke נכשל — בדוק קונפיג/גישה ל-DB"
  else
    echo "⌁ אין scripts/db-smoke.sh — מדלג."
  fi

  log "Newman Smoke (אם יש קובץ Postman)"
  if [[ -f "postman/rsoc-db-smoke.json" ]]; then
    if ! have newman; then npm i -g newman || true; fi
    newman run postman/rsoc-db-smoke.json || echo "⚠️ Newman נכשל — בדוק endpoints/סביבה"
  else
    echo "⌁ אין postman/rsoc-db-smoke.json — מדלג."
  fi

  log "מוכן לפיתוח"
  if [[ -d "services/api" ]]; then
    echo "פיתוח לוקאלי:"
    echo "  cd services/api && npm install && npm run dev"
  fi
  echo -e "\n✅ סיום: השירות רץ ב-$URL"
}

main "$@"

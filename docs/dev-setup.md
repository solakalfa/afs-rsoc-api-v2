# RSOC Dev Setup Guide

This document describes how to reliably start a local/staging dev environment for `afs-rsoc-api-v2`.

---

## Prerequisites
- Node.js v18+
- Docker installed (for Postgres if not running locally)
- gcloud CLI configured and authenticated

---

## One‑liner daily start (Linux/Mac)
```bash
gcloud config set project afs-rsoc-api-v2 && gcloud config set run/region us-central1 && cd ~/afs-rsoc-api-v2 && git fetch origin && git checkout master && git pull --ff-only && chmod +x scripts/start-day.sh && ./scripts/start-day.sh -p afs-rsoc-api
```

## One‑liner daily start (Windows PowerShell)
```powershell
gcloud config set project afs-rsoc-api-v2; `
gcloud config set run/region us-central1; `
cd ~/afs-rsoc-api-v2; `
git fetch origin; git checkout master; git pull --ff-only; `
bash scripts/start-day.sh -p afs-rsoc-api
```

---

## start-day.sh responsibilities
1. Export required environment variables (`DATABASE_URL`, `RSOC_API_TOKEN`).
2. Check Postgres connectivity (`pg_isready`).
3. Run pending migrations (from `sql/migrations/`).
4. Smoke tests:
   - `curl http://127.0.0.1:8080/api/health` → expect `{ok:true}`.
   - Auth check: invalid token returns 401.
   - Conversion happy flow returns 201.
5. Print clear status: ✅ OK / ❌ FAIL per check.

---

## Troubleshooting quick commands
- **Restart Postgres (local docker)**:
  ```bash
  docker compose -f docker/postgres.yml up -d
  ```
- **Reset DB**:
  ```bash
  psql $DATABASE_URL -c "DROP SCHEMA public CASCADE; CREATE SCHEMA public;"
  ```
- **Re‑set secrets**:
  ```bash
  ./scripts/secret-set.sh
  ```

---

## Next step
Once `start-day.sh` passes ✅, run Postman smoke tests from `postman/collections/m22-mvp-smoke.postman_collection.json`.

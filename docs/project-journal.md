# Project Journal

## [2025-09-18] Start M2.1 — Auth & Validation

- התחלה רשמית של M2.1 (Auth & Validation).
- נוסף Bearer token middleware (401).
- נוסף validation פר־נתיב ל־tracking/convert (422 JSON אחיד).
- נבנה קובץ Postman (rsoc-auth-validation.json) עם בדיקות ל־happy path + 401/422.
- Daily Start script עודכן: בחירת פרויקט afs-rsoc-api-v2, שליפת STG_URL, הרצת Newman אוטומטית.
- Newman רץ בהצלחה מול STG (לאחר חיבור לחשבון GCP והגדרת STG_URL).
- סטטוס: ✅ קוד ובדיקות מוכנים; ⚠️ טרם בוצע עדכון מלא ל־docs/openapi.yaml.
- זמן בפועל עד כה: ~2 שעות (GPT + אני).

## 2025-09-18
- Added Technical Execution Log (source-of-truth canvas). Aligned M1→M2 tasks.
- Verified STG service is healthy on `/api/health`. Noted `/api/health-db` needs route check.

## 2025-09-17
- Deployed latest STG revision via `scripts/quickstart.sh`. Newman smoke OK.

## 2025-09-16
- Confirmed secrets present: `RSOC_API_TOKEN_STG`, `DATABASE_URL_STG`. Cloud SQL reachable.


## 2025-09-17
- Deployed afs-rsoc-api-stg revision 00015-rls (Cloud Run).
- Health check `/api/health` returns ok:true, db:true.
- Secrets (RSOC_API_TOKEN_STG, DATABASE_URL_STG) attached and verified.
- Middlewares (auth, traceId, rateLimit, validate, idempotency) added under services/api/.
- Branch feat/m2-harden-core created and pushed.
Next: prepare and run Postman/Newman tests for API Hardening (M2.3).

## Date: 2025-09-17 (Asia/Jerusalem)

Context: Continued from “RSOC API – Reset & Clean Stage.1”. Cloud Shell + GitHub repo afs-rsoc-api-v2.

What happened:

Pulled latest (git pull) → repo up to date.

Ran ./scripts/quickstart.sh → GCP project set; IAM policies on secrets updated (RSOC_API_TOKEN_STG, DATABASE_URL_STG); Cloud Run deploy OK; new Revision created successfully.

Current state:

Cloud Run service healthy; secrets wired; DB reachable via DATABASE_URL_STG.

Reset/Clean flow works end-to-end.

Decisions / Notes:

Keep quickstart.sh as the single-entry deploy routine.

Proceed to M2 validation + hardening.

Next actions:

Smoke & health checks (HTTP + DB) and store outputs in /artifacts/.

Begin M2 API hardening scaffold: auth, rate limits, validation, idempotency, traceId.

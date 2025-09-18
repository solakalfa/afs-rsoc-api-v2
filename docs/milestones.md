# Milestones — Status (as of 2025-09-18)

## M1 — DB & Health ✅
- Cloud Run (STG) live: `afs-rsoc-api-stg` — `/api/health` OK
- Cloud SQL Postgres connected
- Schema created: `events`, `identities`, `conversions`, `outbox`
- Migrations applied
- Secrets set: `DATABASE_URL_STG`, `RSOC_API_TOKEN_STG`
- Scripts working: `quickstart.sh`, `start-day.sh`
- Newman smoke (DB/Health) passed

## M2 — Hardening + Outbound CAPI Worker (in progress)
1. Auth + Validation (401/422) for `tracking` / `convert`
2. Rate limiting (429) + headers
3. Idempotency-Key for `convert`
4. TraceId logging for all requests
5. Outbound CAPI Worker (outbox → CAPI, retries, DLQ, metrics)
6. CI: Newman (happy + 401/422/429 + idempotency), k6 baseline (p95/p99)
7. Docs: OpenAPI/Redoc sync

> Work order: 1 → 3 → 2 → 4 → 5 → 6 → 7

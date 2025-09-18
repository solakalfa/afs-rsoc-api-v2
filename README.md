# RSOC API (afs-rsoc-api-v2)

Attribution Hub API — GCP Cloud Run + Cloud SQL (Postgres).

## Branch Policy
Work only on `master`. Do not edit via GitHub UI (no patch branches).


## Daily Start
```bash
gcloud config set project afs-rsoc-api-v2 && \
gcloud config set run/region us-central1 && \
cd ~/afs-rsoc-api-v2 && \
git fetch origin && git checkout master && git pull --ff-only && \
chmod +x scripts/start-day.sh && ./scripts/start-day.sh -p afs-rsoc-api-v2

Context Pulse (quick check)
SVC=$(gcloud run services list --format='value(metadata.name)' | grep ^afs-rsoc-api | head -n1)
URL=$(gcloud run services describe "$SVC" --format='value(status.url)')
echo "proj=$(gcloud config get-value core/project) svc=$SVC url=$URL"
curl -sS "$URL/api/health"

Deploy / Bootstrap
chmod +x scripts/quickstart.sh && ./scripts/quickstart.sh

Health Endpoints

/api/health

/api/health-db

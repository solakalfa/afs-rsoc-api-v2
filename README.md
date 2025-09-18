# RSOC API (afs-rsoc-api-v2)

Attribution Hub API — GCP Cloud Run + Cloud SQL (Postgres).

## Daily Start
```bash
gcloud config set project afs-rsoc-api-v2 && \
gcloud config set run/region us-central1 && \
cd ~/afs-rsoc-api-v2 && \
git fetch origin && git checkout master && git pull --ff-only && \
chmod +x scripts/start-day.sh && ./scripts/start-day.sh -p afs-rsoc-api-v2

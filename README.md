# RSOC API (v2) – Bootstrap

## דרישות
- Node.js 20+
- חשבון Google Cloud עם הרשאות ל-Cloud Run + Secret Manager

## הרצה לוקאלית
```bash
npm i
AUTH_TOKEN=devtoken PORT=8080 npm start
# לשונית אחרת
curl -s localhost:8080/api/health | jq .
```

## דיפלוי Cloud Run (STG)
```bash
gcloud auth login
gcloud config set project <PROJECT_ID>

# יצירת סיקרטים (פעם אחת)
echo -n 'stg-token-CHANGE-ME' | gcloud secrets create RSOC_API_TOKEN_STG --data-file=-
echo -n 'postgres://USER:PWD@HOST:5432/DBNAME' | gcloud secrets create DATABASE_URL_STG --data-file=-

# דיפלוי בעזרת Buildpacks (ללא Dockerfile)
gcloud run deploy afs-rsoc-api-stg   --region us-central1   --source .   --allow-unauthenticated   --set-secrets AUTH_TOKEN=RSOC_API_TOKEN_STG:latest,DATABASE_URL=DATABASE_URL_STG:latest
```

## Smoke ל-STG
```bash
BASE=https://<SERVICE-URL>
TOKEN=stg-token-CHANGE-ME

curl -i $BASE/api/health
curl -i -H "Authorization: Bearer $TOKEN" -H "Content-Type: application/json"   -d '{"utm_source":"fb","source":"facebook","account_id":"1","campaign_id":"2","adset_id":"3","ad_id":"4"}'   $BASE/api/tracking

curl -i -H "Authorization: Bearer $TOKEN" -H "Content-Type: application/json"   -d '{"click_id":"<uuid>","value":1.23,"currency":"USD"}'   $BASE/api/convert
```
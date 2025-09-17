#!/usr/bin/env bash
set -euo pipefail
# שימוש: scripts/secret-set.sh <SECRET_NAME> "<VALUE>"
if [ $# -lt 2 ]; then echo "usage: $0 SECRET_NAME VALUE"; exit 1; fi
NAME="$1"; VAL="$2"
echo -n "$VAL" > /tmp/secret.val
( gcloud secrets create "$NAME" --data-file=/tmp/secret.val ) || \
gcloud secrets versions add "$NAME" --data-file=/tmp/secret.val
echo "✅ secret $NAME updated"

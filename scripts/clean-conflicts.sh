#!/usr/bin/env bash
set -euo pipefail

echo "Scanning for duplicate/legacy events routers..."
git ls-files | grep -E 'services/api/(src/)?routes(/api)?/events\.mjs$' || echo "No events.mjs tracked."
echo "If you see files outside services/api/src/routes/api/events.mjs, remove them."

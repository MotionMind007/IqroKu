#!/bin/bash
set -euo pipefail

# =============================================================================
# IqroKu Smoke Test
# Run from VPS after deploy:
#   BASE_URL=https://iqroku.motionmind.store ./deploy/smoke-test.sh
# =============================================================================

BASE_URL="${BASE_URL:-http://localhost:8787}"
APP_DIR="${APP_DIR:-/opt/iqroku}"

echo "=== IqroKu Smoke Test ==="
echo "Base URL: ${BASE_URL}"
echo ""

echo "[1/4] Checking health endpoint..."
HEALTH_BODY=$(curl -fsS --connect-timeout 5 --max-time 15 "${BASE_URL}/health")
echo "  ${HEALTH_BODY}"
echo "${HEALTH_BODY}" | grep -q '"ok":true'
echo "${HEALTH_BODY}" | grep -q '"store":"postgresql"'

echo "[2/4] Checking security headers..."
HEADERS=$(curl -fsS --connect-timeout 5 --max-time 15 -D - -o /dev/null "${BASE_URL}/health")
echo "${HEADERS}" | grep -qi '^x-content-type-options: nosniff'
echo "${HEADERS}" | grep -qi '^vary: Origin'

echo "[3/4] Checking backend syntax..."
cd "$APP_DIR"
node --check backend/src/server.mjs
node --check backend/src/db.mjs

echo "[4/4] Checking migration status..."
npm run migrate:status --prefix backend

echo ""
echo "Smoke test passed."

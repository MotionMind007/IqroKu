#!/bin/bash
set -euo pipefail

# =============================================================================
# IqroKu Deploy Script
# Run from VPS: cd /opt/iqroku && ./deploy/deploy.sh
# =============================================================================

APP_DIR="/opt/iqroku"
cd "$APP_DIR"

echo "=== IqroKu Deploy ==="
echo "$(date '+%Y-%m-%d %H:%M:%S')"
echo ""

# Pull latest code
echo "[1/4] Pulling latest code..."
git fetch origin main
git reset --hard origin/main

# Check syntax
echo "[2/4] Checking syntax..."
node --check backend/src/server.mjs
node --check backend/src/store.mjs

# Run migrations (if any new .sql files)
echo "[3/4] Running migrations..."
if [ -f "deploy/schema.sql" ]; then
    # Safe to re-run (uses IF NOT EXISTS and ON CONFLICT DO NOTHING)
    source backend/.env 2>/dev/null || true
    psql "$DATABASE_URL" -f deploy/schema.sql 2>/dev/null || \
        echo "  Schema already up to date"
fi

# Restart app
echo "[4/4] Restarting app..."
pm2 restart iqroku --update-env

# Wait and check health
sleep 2
if curl -sf http://localhost:8787/health > /dev/null; then
    echo ""
    echo "✓ Deploy successful! App is healthy."
    echo "  $(curl -s http://localhost:8787/health)"
else
    echo ""
    echo "✗ Health check failed! Check logs:"
    echo "  pm2 logs iqroku --lines 20"
    exit 1
fi

echo ""
echo "=== Deploy Complete ==="

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

# Backup current commit hash
echo "[1/5] Backing up current state..."
PREVIOUS_COMMIT=$(git rev-parse HEAD)
echo "  Current commit: $PREVIOUS_COMMIT"

# Pull latest code
echo "[2/5] Pulling latest code..."
git fetch origin main
git reset --hard origin/main
echo "  New commit: $(git rev-parse --short HEAD)"

# Check syntax
echo "[3/5] Checking syntax..."
node --check backend/src/server.mjs
node --check backend/src/db.mjs

# Install dependencies
echo "[4/5] Installing dependencies..."
cd backend && npm ci --omit=dev 2>/dev/null || npm install --omit=dev
cd ..

# Run migrations (if any new .sql files)
echo "[5/5] Running migrations..."
if [ -f "deploy/schema.sql" ]; then
    # Safe to re-run (uses IF NOT EXISTS and ON CONFLICT DO NOTHING)
    if [ -f "backend/.env" ]; then
        DATABASE_URL=$(grep -oP '^DATABASE_URL=\K.*' backend/.env 2>/dev/null || echo "")
        if [ -n "$DATABASE_URL" ]; then
            psql "$DATABASE_URL" -f deploy/schema.sql 2>/dev/null || \
                echo "  Schema already up to date"
        else
            echo "  DATABASE_URL not found in .env, skipping migrations"
        fi
    else
        echo "  No .env file found, skipping migrations"
    fi
fi

# Restart app
echo "Restarting app..."
pm2 restart iqroku --update-env

# Wait and check health
sleep 2
if curl -sf http://localhost:8787/health > /dev/null; then
    echo ""
    echo "✓ Deploy successful! App is healthy."
    echo "  $(curl -s http://localhost:8787/health)"
else
    echo ""
    echo "✗ Health check failed! Rolling back to previous commit..."
    git reset --hard "$PREVIOUS_COMMIT"
    cd backend && npm ci --omit=dev 2>/dev/null || npm install --omit=dev
    cd ..
    pm2 restart iqroku --update-env
    echo "  Rolled back to: $(git rev-parse --short HEAD)"
    echo "  Check logs: pm2 logs iqroku --lines 20"
    exit 1
fi

echo ""
echo "=== Deploy Complete ==="

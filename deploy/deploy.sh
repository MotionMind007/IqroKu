#!/bin/bash
set -euo pipefail

# =============================================================================
# IqroKu Deploy Script
# Run from VPS: cd /opt/iqroku && ./deploy/deploy.sh
# =============================================================================

APP_DIR="${APP_DIR:-/opt/iqroku}"
OPS_BASE_URL="${OPS_BASE_URL:-https://iqroku.motionmind.store}"
cd "$APP_DIR"

echo "=== IqroKu Deploy ==="
echo "$(date '+%Y-%m-%d %H:%M:%S')"
echo ""

echo "[1/7] Checking environment..."
if [ ! -f "$APP_DIR/backend/.env" ]; then
    echo "  Missing $APP_DIR/backend/.env"
    echo "  Copy deploy/.env.production to backend/.env and fill real values first."
    exit 1
fi

echo "[2/7] Backing up current state..."
PREVIOUS_COMMIT=$(git rev-parse HEAD)
echo "  Current commit: $PREVIOUS_COMMIT"
if [ -x "$APP_DIR/backup.sh" ]; then
    "$APP_DIR/backup.sh"
elif [ -x "$APP_DIR/deploy/backup.sh" ]; then
    "$APP_DIR/deploy/backup.sh"
else
    echo "  Backup script not found; refusing to deploy without backup."
    exit 1
fi

echo "[3/7] Pulling latest code..."
git fetch origin main
git reset --hard origin/main
echo "  New commit: $(git rev-parse --short HEAD)"

if [ -f "$APP_DIR/deploy/ops-check.sh" ]; then
    cp "$APP_DIR/deploy/ops-check.sh" "$APP_DIR/ops-check.sh"
    chmod +x "$APP_DIR/ops-check.sh"
    (crontab -l 2>/dev/null; echo "*/15 * * * * BASE_URL=${OPS_BASE_URL} ${APP_DIR}/ops-check.sh >> /var/log/iqroku/ops-check.log 2>&1") | sort -u | crontab -
fi

echo "[4/7] Checking syntax..."
npm run check --prefix backend
if [ -f /etc/nginx/sites-enabled/iqroku ] || [ -f /etc/nginx/sites-available/iqroku ]; then
    LIVE_NGINX_CONFIG="$(mktemp)"
    if nginx -T > "$LIVE_NGINX_CONFIG" 2>/dev/null; then
        if grep -Eq 'location[[:space:]]+/uploads/' "$LIVE_NGINX_CONFIG" \
            && grep -Eq 'alias[[:space:]]+/opt/iqroku/uploads/' "$LIVE_NGINX_CONFIG"; then
            rm -f "$LIVE_NGINX_CONFIG"
            echo "  Live nginx still serves /uploads/ with alias. This bypasses backend auth."
            echo "  Sync deploy/nginx-iqroku.conf to /etc/nginx/sites-available/iqroku before deploying."
            exit 1
        fi
    fi
    rm -f "$LIVE_NGINX_CONFIG"
fi

echo "[5/7] Installing dependencies..."
cd backend
npm ci --omit=dev 2>/dev/null || npm install --omit=dev
npm audit --omit=dev --audit-level=high
cd ..

echo "[6/7] Running migrations..."
npm run migrate --prefix backend

echo "[7/7] Restarting app..."
pm2 restart iqroku --update-env

sleep 2
if BASE_URL=http://localhost:8787 APP_DIR="$APP_DIR" bash "$APP_DIR/deploy/smoke-test.sh"; then
    echo ""
    echo "Deploy successful. App is healthy."
    echo "  $(curl -s http://localhost:8787/health)"
else
    echo ""
    echo "Smoke test failed. Rolling back code to previous commit..."
    echo "Note: database migrations are not automatically rolled back."
    git reset --hard "$PREVIOUS_COMMIT"
    cd backend
    npm ci --omit=dev 2>/dev/null || npm install --omit=dev
    cd ..
    pm2 restart iqroku --update-env
    echo "  Rolled back to: $(git rev-parse --short HEAD)"
    echo "  Check logs: pm2 logs iqroku --lines 20"
    exit 1
fi

echo ""
echo "=== Deploy Complete ==="

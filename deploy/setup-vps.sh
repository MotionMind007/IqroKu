#!/bin/bash
set -euo pipefail

# =============================================================================
# IqroKu VPS Setup Script (Ubuntu 24, one-time)
# Run as root: sudo ./setup-vps.sh
# =============================================================================

echo "=== IqroKu VPS Setup ==="
DOMAIN="${DOMAIN:-iqroku.motionmind.store}"
LETSENCRYPT_EMAIL="${LETSENCRYPT_EMAIL:-admin@motionmind.store}"
APP_DIR="${APP_DIR:-/opt/iqroku}"
DB_NAME="${DB_NAME:-iqroku_db}"
DB_USER="${DB_USER:-iqroku}"

echo "Domain: ${DOMAIN}"
echo ""

if [[ ! "$DB_NAME" =~ ^[a-zA-Z0-9_]+$ ]] || [[ ! "$DB_USER" =~ ^[a-zA-Z0-9_]+$ ]]; then
    echo "DB_NAME and DB_USER must contain only letters, numbers, and underscores."
    exit 1
fi

# --- 1. System packages ---
echo "[1/7] Installing system packages..."
apt-get update -qq
apt-get install -y -qq curl git nginx postgresql postgresql-contrib certbot python3-certbot-nginx

# --- 2. Node.js 22 LTS (if not installed) ---
if ! command -v node &> /dev/null || [[ $(node -v | cut -d'.' -f1 | tr -d 'v') -lt 20 ]]; then
    echo "[2/7] Installing Node.js 22..."
    curl -fsSL https://deb.nodesource.com/setup_22.x | bash -
    apt-get install -y -qq nodejs
else
    echo "[2/7] Node.js already installed: $(node -v)"
fi

# --- 3. PM2 ---
if ! command -v pm2 &> /dev/null; then
    echo "[3/7] Installing PM2..."
    npm install -g pm2
    pm2 startup systemd -u root --hp /root
else
    echo "[3/7] PM2 already installed"
fi

# --- 4. PostgreSQL setup ---
echo "[4/7] Setting up PostgreSQL..."
DB_PASS=$(openssl rand -hex 16)

if sudo -u postgres psql -tc "SELECT 1 FROM pg_roles WHERE rolname='${DB_USER}'" | grep -q 1; then
    sudo -u postgres psql -c "ALTER USER ${DB_USER} WITH PASSWORD '${DB_PASS}';"
else
    sudo -u postgres psql -c "CREATE USER ${DB_USER} WITH PASSWORD '${DB_PASS}';"
fi

sudo -u postgres psql -tc "SELECT 1 FROM pg_database WHERE datname='${DB_NAME}'" | grep -q 1 || \
    sudo -u postgres psql -c "CREATE DATABASE ${DB_NAME} OWNER ${DB_USER};"

sudo -u postgres psql -c "GRANT ALL PRIVILEGES ON DATABASE ${DB_NAME} TO ${DB_USER};"
sudo -u postgres psql -d ${DB_NAME} -c "GRANT ALL ON SCHEMA public TO ${DB_USER};"

echo "  Database: ${DB_NAME}"
echo "  User: ${DB_USER}"
echo ""
echo "  Database password was written to ${APP_DIR}/backend/.env (mode 600)."
echo ""

# --- 5. App directory ---
echo "[5/7] Setting up app directory..."
mkdir -p "$APP_DIR"
mkdir -p "$APP_DIR/uploads/audio"
mkdir -p /var/log/iqroku
mkdir -p "$APP_DIR/backups"
mkdir -p /var/www/certbot

# Clone or pull repo
if [ ! -d "${APP_DIR}/.git" ]; then
    git clone https://github.com/MotionMind007/IqroKu.git "$APP_DIR"
else
    cd "$APP_DIR" && git pull origin main
fi

# Run schema
echo "  Running database schema..."
sudo -u postgres psql -d "${DB_NAME}" -f "${APP_DIR}/deploy/schema.sql"

# Install backend dependencies
echo "  Installing backend dependencies..."
cd "${APP_DIR}/backend" && npm install --omit=dev
cd "$APP_DIR"

# Create .env
ADMIN_TOKEN=$(openssl rand -hex 32)
SESSION_SECRET=$(openssl rand -hex 32)

cat > "${APP_DIR}/backend/.env" << EOF
NODE_ENV=production
PORT=8787
DATABASE_URL=postgresql://${DB_USER}:${DB_PASS}@localhost:5432/${DB_NAME}
ALLOWED_ORIGIN=https://${DOMAIN}
IQROKU_ADMIN_TOKEN=${ADMIN_TOKEN}
SESSION_SECRET=${SESSION_SECRET}
MAX_BODY_SIZE=5242880
MAX_AUDIO_UPLOAD_BYTES=5242880
IQROKU_UPLOAD_ROOT=${APP_DIR}/uploads
REQUIRE_EMAIL_VERIFICATION=false
AUTH_LINK_BASE_URL=https://${DOMAIN}
EMAIL_VERIFICATION_TTL_MINUTES=1440
PASSWORD_RESET_TTL_MINUTES=30
RATE_WINDOW_MS=60000
RATE_MAX_AUTH=10
RATE_MAX_GENERAL=120
# Optional FCM push notification service account.
# Prefer a root-readable file and set FIREBASE_SERVICE_ACCOUNT_PATH.
# FIREBASE_SERVICE_ACCOUNT_PATH=${APP_DIR}/secrets/firebase-service-account.json
# FIREBASE_SERVICE_ACCOUNT_JSON=
EOF

chmod 600 "${APP_DIR}/backend/.env"

echo "  Admin token was written to ${APP_DIR}/backend/.env (mode 600)."
echo ""
echo "  Recording idempotent migration baseline..."
npm run migrate --prefix "${APP_DIR}/backend"
echo ""

# --- 6. Nginx ---
echo "[6/7] Configuring Nginx..."
cat > /etc/nginx/sites-available/iqroku << EOF
server {
    listen 80;
    listen [::]:80;
    server_name ${DOMAIN};

    location /.well-known/acme-challenge/ {
        root /var/www/certbot;
    }

    location / {
        return 200 'IqroKu certificate bootstrap';
        add_header Content-Type text/plain;
    }
}
EOF

# Don't overwrite if symlink exists
if [ ! -L "/etc/nginx/sites-enabled/iqroku" ]; then
    ln -s /etc/nginx/sites-available/iqroku /etc/nginx/sites-enabled/iqroku
fi

nginx -t
systemctl reload nginx

# --- 7. SSL Certificate ---
echo "[7/7] Obtaining SSL certificate..."
if ! certbot certonly --webroot -w /var/www/certbot -d "${DOMAIN}" --non-interactive --agree-tos --email "${LETSENCRYPT_EMAIL}"; then
    echo "  SSL cert issue failed. Make sure DNS A record points to this server, then run:"
    echo "  certbot certonly --webroot -w /var/www/certbot -d ${DOMAIN}"
    exit 1
fi

sed "s|iqroku.motionmind.store|${DOMAIN}|g" "${APP_DIR}/deploy/nginx-iqroku.conf" > /etc/nginx/sites-available/iqroku
nginx -t && systemctl reload nginx

# --- Start app ---
echo ""
echo "=== Starting IqroKu ==="
cd "$APP_DIR"
sed "s|/opt/iqroku|${APP_DIR}|g" deploy/ecosystem.config.cjs > ecosystem.config.cjs
pm2 start ecosystem.config.cjs --update-env
pm2 save

# --- Setup daily backup cron ---
cp deploy/backup.sh "${APP_DIR}/backup.sh"
chmod +x "${APP_DIR}/backup.sh"
(crontab -l 2>/dev/null; echo "0 3 * * * ${APP_DIR}/backup.sh >> /var/log/iqroku/backup.log 2>&1") | sort -u | crontab -

# --- Setup operations check cron ---
cp deploy/ops-check.sh "${APP_DIR}/ops-check.sh"
chmod +x "${APP_DIR}/ops-check.sh"
(crontab -l 2>/dev/null; echo "*/15 * * * * BASE_URL=https://${DOMAIN} ${APP_DIR}/ops-check.sh >> /var/log/iqroku/ops-check.log 2>&1") | sort -u | crontab -

# --- Setup weekly restore drill cron ---
cp deploy/weekly-restore-drill.sh "${APP_DIR}/weekly-restore-drill.sh"
chmod +x "${APP_DIR}/weekly-restore-drill.sh"
(crontab -l 2>/dev/null; echo "30 4 * * 0 ${APP_DIR}/weekly-restore-drill.sh >> /var/log/iqroku/restore-drill.log 2>&1") | sort -u | crontab -

# --- Setup auth cleanup cron ---
(crontab -l 2>/dev/null; echo "0 */6 * * * sudo -u postgres psql -d ${DB_NAME} -c \"DELETE FROM sessions WHERE expires_at < NOW(); DELETE FROM auth_tokens WHERE expires_at < NOW() - INTERVAL '7 days';\"") | sort -u | crontab -

echo ""
echo "============================================"
echo "  IqroKu Setup Complete!"
echo "============================================"
echo ""
echo "  URL:    https://${DOMAIN}"
echo "  Admin:  https://${DOMAIN}/admin"
echo "  Health: https://${DOMAIN}/health"
echo ""
echo "  Commands:"
echo "    pm2 status          - Check process status"
echo "    pm2 logs iqroku     - View logs"
echo "    pm2 restart iqroku  - Restart app"
echo ""
echo "  Deploy new version:"
echo "    cd ${APP_DIR} && ./deploy/deploy.sh"
echo ""
echo "  IMPORTANT: Save these values somewhere safe:"
echo "    Production secrets are in ${APP_DIR}/backend/.env"
echo "============================================"

#!/bin/bash
set -euo pipefail

# =============================================================================
# IqroKu VPS Setup Script (Ubuntu 24, one-time)
# Run as root: sudo ./setup-vps.sh
# =============================================================================

echo "=== IqroKu VPS Setup ==="
echo "Domain: iqroku.motionmind.store"
echo ""

# --- 1. System packages ---
echo "[1/7] Installing system packages..."
apt-get update -qq
apt-get install -y -qq curl git postgresql postgresql-contrib certbot python3-certbot-nginx

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
DB_NAME="iqroku_db"
DB_USER="iqroku"
DB_PASS=$(openssl rand -hex 16)

# Create user and database if they don't exist
sudo -u postgres psql -tc "SELECT 1 FROM pg_roles WHERE rolname='${DB_USER}'" | grep -q 1 || \
    sudo -u postgres psql -c "CREATE USER ${DB_USER} WITH PASSWORD '${DB_PASS}';"

sudo -u postgres psql -tc "SELECT 1 FROM pg_database WHERE datname='${DB_NAME}'" | grep -q 1 || \
    sudo -u postgres psql -c "CREATE DATABASE ${DB_NAME} OWNER ${DB_USER};"

sudo -u postgres psql -c "GRANT ALL PRIVILEGES ON DATABASE ${DB_NAME} TO ${DB_USER};"
sudo -u postgres psql -d ${DB_NAME} -c "GRANT ALL ON SCHEMA public TO ${DB_USER};"

echo "  Database: ${DB_NAME}"
echo "  User: ${DB_USER}"
echo "  Password: ${DB_PASS}"
echo ""
echo "  >>> SAVE THIS PASSWORD! <<<"
echo ""

# --- 5. App directory ---
echo "[5/7] Setting up app directory..."
mkdir -p /opt/iqroku
mkdir -p /opt/iqroku/uploads/audio
mkdir -p /var/log/iqroku
mkdir -p /opt/iqroku/backups

# Clone or pull repo
if [ ! -d "/opt/iqroku/.git" ]; then
    git clone https://github.com/MotionMind007/IqroKu.git /opt/iqroku
else
    cd /opt/iqroku && git pull origin main
fi

# Run schema
echo "  Running database schema..."
sudo -u postgres psql -d ${DB_NAME} -f /opt/iqroku/deploy/schema.sql

# Create .env
ADMIN_TOKEN=$(openssl rand -hex 32)
SESSION_SECRET=$(openssl rand -hex 32)

cat > /opt/iqroku/backend/.env << EOF
NODE_ENV=production
PORT=8787
DATABASE_URL=postgresql://${DB_USER}:${DB_PASS}@localhost:5432/${DB_NAME}
IQROKU_ADMIN_TOKEN=${ADMIN_TOKEN}
SESSION_SECRET=${SESSION_SECRET}
MAX_BODY_SIZE=5242880
RATE_WINDOW_MS=60000
RATE_MAX_AUTH=10
RATE_MAX_GENERAL=120
EOF

chmod 600 /opt/iqroku/backend/.env

echo "  Admin token: ${ADMIN_TOKEN}"
echo "  >>> SAVE THIS TOKEN for admin dashboard access! <<<"
echo ""

# --- 6. Nginx ---
echo "[6/7] Configuring Nginx..."
cp /opt/iqroku/deploy/nginx-iqroku.conf /etc/nginx/sites-available/iqroku

# Don't overwrite if symlink exists
if [ ! -L "/etc/nginx/sites-enabled/iqroku" ]; then
    ln -s /etc/nginx/sites-available/iqroku /etc/nginx/sites-enabled/iqroku
fi

# Test nginx config (will fail on SSL cert not yet existing, that's OK)
echo "  Testing nginx config (SSL cert not yet issued, expect warning)..."
nginx -t 2>&1 || true

# --- 7. SSL Certificate ---
echo "[7/7] Obtaining SSL certificate..."
# Temporarily comment out SSL lines for initial cert issue
# Use standalone or webroot method
certbot certonly --nginx -d iqroku.motionmind.store --non-interactive --agree-tos --email admin@motionmind.store || \
    echo "  SSL cert issue failed. Make sure DNS A record points to this server, then run:"
    echo "  certbot certonly --nginx -d iqroku.motionmind.store"

# Reload nginx with SSL
nginx -t && systemctl reload nginx

# --- Start app ---
echo ""
echo "=== Starting IqroKu ==="
cd /opt/iqroku
cp deploy/ecosystem.config.cjs .
pm2 start ecosystem.config.cjs
pm2 save

# --- Setup daily backup cron ---
cp deploy/backup.sh /opt/iqroku/backup.sh
chmod +x /opt/iqroku/backup.sh
(crontab -l 2>/dev/null; echo "0 3 * * * /opt/iqroku/backup.sh >> /var/log/iqroku/backup.log 2>&1") | sort -u | crontab -

# --- Setup session cleanup cron ---
(crontab -l 2>/dev/null; echo "0 */6 * * * sudo -u postgres psql -d ${DB_NAME} -c \"DELETE FROM sessions WHERE expires_at < NOW();\"") | sort -u | crontab -

echo ""
echo "============================================"
echo "  IqroKu Setup Complete!"
echo "============================================"
echo ""
echo "  URL:    https://iqroku.motionmind.store"
echo "  Admin:  https://iqroku.motionmind.store/admin?token=${ADMIN_TOKEN}"
echo "  Health: https://iqroku.motionmind.store/health"
echo ""
echo "  Commands:"
echo "    pm2 status          - Check process status"
echo "    pm2 logs iqroku     - View logs"
echo "    pm2 restart iqroku  - Restart app"
echo ""
echo "  Deploy new version:"
echo "    cd /opt/iqroku && ./deploy/deploy.sh"
echo ""
echo "  IMPORTANT: Save these values somewhere safe:"
echo "    DB Password:  ${DB_PASS}"
echo "    Admin Token:  ${ADMIN_TOKEN}"
echo "============================================"

# IqroKu VPS Deployment Guide

Target: Ubuntu 24 / 2 core / 4GB RAM
Domain: iqroku.motionmind.store
Server already has other services running.

## Prerequisites

- SSH access to VPS
- Domain `iqroku.motionmind.store` pointing to VPS IP (A record)
- Nginx already installed (shared with other services)

## Quick Start

```bash
# 1. Copy deploy folder to VPS
scp -r deploy/ user@your-vps-ip:/tmp/iqroku-deploy/

# 2. SSH into VPS
ssh user@your-vps-ip

# 3. Run setup (one-time)
cd /tmp/iqroku-deploy
chmod +x setup-vps.sh
sudo ./setup-vps.sh

# 4. Deploy app
chmod +x deploy.sh
./deploy.sh

# 5. Run database migrations after code deploy
cd /opt/iqroku
npm run migrate --prefix backend
```

## File Overview

| File | Purpose |
|------|---------|
| `setup-vps.sh` | One-time server setup (PostgreSQL, Node, PM2, Nginx, SSL) |
| `deploy.sh` | Pull latest code & restart (run on each deploy) |
| `ecosystem.config.cjs` | PM2 process config |
| `nginx-iqroku.conf` | Nginx site config for iqroku.motionmind.store |
| `schema.sql` | PostgreSQL database schema |
| `migrations/` | Idempotent schema changes applied by `npm run migrate --prefix backend` |
| `.env.production` | Environment template (fill in secrets) |
| `backup.sh` | Daily database backup script |

## After Setup

- App runs at: https://iqroku.motionmind.store
- Admin: https://iqroku.motionmind.store/admin?token=YOUR_ADMIN_TOKEN
- Health: https://iqroku.motionmind.store/health
- Logs: `pm2 logs iqroku`
- Restart: `pm2 restart iqroku`
- Deploy new version: `cd /opt/iqroku && ./deploy/deploy.sh`
- Migration status: `cd /opt/iqroku && npm run migrate:status --prefix backend`

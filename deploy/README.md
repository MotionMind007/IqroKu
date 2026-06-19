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

# 5. Check database migrations
cd /opt/iqroku
npm run migrate:status --prefix backend

# 6. Run smoke test
BASE_URL=https://iqroku.motionmind.store ./deploy/smoke-test.sh
```

## Staging / Production Dry-Run

Sebelum dipakai user asli, jalankan dry-run ini di VPS/staging:

```bash
cd /opt/iqroku
git fetch origin main
git status
npm run migrate:status --prefix backend
npm run check --prefix backend
npm test --prefix backend
BASE_URL=https://iqroku.motionmind.store ./deploy/smoke-test.sh
```

Pastikan live Nginx tidak melayani upload lewat `alias`. Audio harus lewat backend agar authorization tetap jalan:

```bash
sudo cp /opt/iqroku/deploy/nginx-iqroku.conf /etc/nginx/sites-available/iqroku
sudo nginx -t
sudo systemctl reload nginx
sudo nginx -T | grep -A8 -n "location /uploads/"
```

Jika memakai file service account Firebase, batasi permission agar hanya owner yang bisa membaca:

```bash
sudo chown iqroku:iqroku /opt/iqroku/secrets/firebase-service-account.json
sudo chmod 600 /opt/iqroku/secrets/firebase-service-account.json
```

Untuk build Android dengan Firebase/FCM, file client config asli harus ada lokal di app:

```bash
cp iqroku_app/android/app/google-services.example.json iqroku_app/android/app/google-services.json
```

Lalu isi/ganti dengan file asli dari Firebase Console. File asli `google-services.json` di-ignore dan tidak boleh di-commit, terutama saat repo masih public.

Lalu tes manual dari HP:

- register/login
- setup parent PIN dan child PIN
- anak rekam bacaan
- parent melihat pending review
- parent approve dan repeat
- anak playback/lanjut sesuai hasil review
- buka jadwal sholat, Qur'an, qiblat, doa, dan murotal

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
| `restore-backup.sh` | Destructive restore helper for restore drills |
| `restore-drill.sh` | Non-destructive backup restore verification using a temporary DB |
| `smoke-test.sh` | Health, header, syntax, and migration smoke test |

## Environment

Actual production secrets live in `/opt/iqroku/backend/.env`; never commit that file.

Required values:

```bash
NODE_ENV=production
PORT=8787
DATABASE_URL=postgresql://...
ALLOWED_ORIGIN=https://iqroku.motionmind.store
IQROKU_ADMIN_TOKEN=<random-hex>
ADMIN_ALLOWED_IPS=
SESSION_SECRET=<random-hex>
MAX_BODY_SIZE=5242880
MAX_AUDIO_UPLOAD_BYTES=5242880
IQROKU_UPLOAD_ROOT=/opt/iqroku/uploads
REQUIRE_EMAIL_VERIFICATION=false
AUTH_LINK_BASE_URL=https://iqroku.motionmind.store
RATE_WINDOW_MS=60000
RATE_MAX_AUTH=10
RATE_MAX_GENERAL=120
# Optional for FCM push notification sending:
FIREBASE_SERVICE_ACCOUNT_PATH=/opt/iqroku/secrets/firebase-service-account.json
```

Firebase Android client config:

- `iqroku_app/android/app/google-services.json` diperlukan untuk build APK/AAB yang memakai Firebase.
- File asli tidak di-track git.
- Template aman ada di `iqroku_app/android/app/google-services.example.json`.
- Kalau repo pernah public dan file asli pernah ter-commit, batasi Android API key di Google Cloud/Firebase Console ke package name dan SHA certificate app.

Admin IP restriction:

- Kosongkan `ADMIN_ALLOWED_IPS` kalau IP admin belum stabil.
- Isi comma/space-separated public IP jika ingin membatasi semua `/admin` route.
- Backend memakai `X-Forwarded-For` dari Nginx saat `TRUST_PROXY=true`.

Contoh:

```bash
ADMIN_ALLOWED_IPS=203.0.113.10,2001:db8::10
```

Auth/session cleanup:

- Backend menjalankan cleanup sessions dan auth tokens expired otomatis tiap 6 jam.
- `setup-vps.sh` juga memasang cron cleanup sebagai backup.
- Interval app bisa diubah dengan `CLEANUP_EXPIRED_AUTH_INTERVAL_MS`; set `0` hanya jika cleanup ditangani scheduler eksternal.

## Backup and Restore

Manual backup:

```bash
cd /opt/iqroku
./backup.sh
ls -lah /opt/iqroku/backups
```

Non-destructive restore drill:

```bash
cd /opt/iqroku
./deploy/restore-drill.sh \
  /opt/iqroku/backups/iqroku_YYYYMMDD_HHMMSS.sql.gz \
  /opt/iqroku/backups/uploads_YYYYMMDD_HHMMSS.tar.gz
```

Notes:

- Drill restores into a temporary database named `iqroku_restore_drill_<timestamp>`.
- Production database is not stopped or modified.
- The temporary database is dropped automatically after the drill passes or fails.
- Set `KEEP_RESTORE_DRILL_DB=YES` only when debugging a failed drill.

Destructive restore on staging only:

```bash
cd /opt/iqroku
CONFIRM_RESTORE=YES ./deploy/restore-backup.sh /opt/iqroku/backups/iqroku_YYYYMMDD_HHMMSS.sql.gz
BASE_URL=https://iqroku.motionmind.store ./deploy/smoke-test.sh
```

Restore with uploads:

```bash
CONFIRM_RESTORE=YES ./deploy/restore-backup.sh \
  /opt/iqroku/backups/iqroku_YYYYMMDD_HHMMSS.sql.gz \
  /opt/iqroku/backups/uploads_YYYYMMDD_HHMMSS.tar.gz
```

## After Setup

- App runs at: https://iqroku.motionmind.store
- Admin: https://iqroku.motionmind.store/admin?token=YOUR_ADMIN_TOKEN
- Health: https://iqroku.motionmind.store/health
- Logs: `pm2 logs iqroku`
- Restart: `pm2 restart iqroku`
- Deploy new version: `cd /opt/iqroku && ./deploy/deploy.sh`
- Migration status: `cd /opt/iqroku && npm run migrate:status --prefix backend`
- Smoke test: `cd /opt/iqroku && BASE_URL=https://iqroku.motionmind.store ./deploy/smoke-test.sh`

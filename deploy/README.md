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
npm run migrate --prefix backend

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
npm run migrate --prefix backend
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
| `ops-check.sh` | Periodic operations check for health, PM2, backups, disk, permissions, and Nginx upload protection |

## Environment

Actual production secrets live in `/opt/iqroku/backend/.env`; never commit that file.

Required values:

```bash
NODE_ENV=production
PORT=8787
DATABASE_URL=postgresql://...
ALLOWED_ORIGIN=https://iqroku.motionmind.store
IQROKU_ADMIN_TOKEN=<random-hex>
ADMIN_CSRF_SECRET=
ADMIN_ALLOWED_IPS=
SESSION_SECRET=<random-hex>
MAX_BODY_SIZE=5242880
MAX_AUDIO_UPLOAD_BYTES=5242880
IQROKU_UPLOAD_ROOT=/opt/iqroku/uploads
REQUIRE_EMAIL_VERIFICATION=false
AUTH_LINK_BASE_URL=https://iqroku.motionmind.store
EMAIL_PROVIDER=none
RESEND_API_KEY=
EMAIL_FROM=IqroKu <noreply@iqroku.motionmind.store>
EMAIL_REPLY_TO=
EMAIL_SEND_TIMEOUT_MS=10000
EMAIL_SEND_RETRIES=2
GOOGLE_VERIFY_TIMEOUT_MS=10000
GOOGLE_VERIFY_RETRIES=2
RATE_WINDOW_MS=60000
RATE_MAX_AUTH=10
RATE_MAX_GENERAL=120
DOKU_ENV=sandbox
DOKU_CLIENT_ID=
DOKU_SECRET_KEY=
DOKU_BASE_URL=https://api-sandbox.doku.com
DOKU_CHECKOUT_RETURN_URL=https://iqroku.motionmind.store/payments/doku/return
DOKU_CHECKOUT_FAILED_URL=https://iqroku.motionmind.store/payments/doku/failed
DOKU_NOTIFICATION_URL=https://iqroku.motionmind.store/payments/doku/webhook
DOKU_CHECKOUT_AMOUNT=49000
DOKU_SEND_TIMEOUT_MS=15000
DOKU_SEND_RETRIES=1
# Optional for FCM push notification sending:
FIREBASE_SERVICE_ACCOUNT_PATH=/opt/iqroku/secrets/firebase-service-account.json
FCM_SEND_TIMEOUT_MS=10000
FCM_SEND_RETRIES=2
FCM_OAUTH_TIMEOUT_MS=10000
FCM_OAUTH_RETRIES=2
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

Logging dan external request reliability:

- Backend menulis structured JSON log untuk request HTTP, retry external request, dan error internal.
- Setiap response membawa header `x-request-id`; header request `x-request-id` dari client/proxy akan dipakai ulang kalau ada.
- External call Google token verification, Resend, DOKU, dan FCM punya timeout + retry konservatif.
- Retry hanya untuk timeout/network error atau HTTP transient seperti `408`, `429`, dan `5xx`; status validasi seperti `400/401/403` tidak diulang.

Email provider:

- Default `EMAIL_PROVIDER=none` agar production tidak bergantung pada email sebelum DNS/API key siap.
- Untuk Resend, verifikasi domain dulu di dashboard Resend, lalu set:

```bash
EMAIL_PROVIDER=resend
RESEND_API_KEY=re_xxx
EMAIL_FROM=IqroKu <noreply@iqroku.motionmind.store>
EMAIL_REPLY_TO=support@iqroku.motionmind.store
```

- Setelah email terkirim end-to-end untuk register, resend verification, dan forgot password, baru pertimbangkan `REQUIRE_EMAIL_VERIFICATION=true`.

DOKU Checkout:

- Mulai dari sandbox: isi `DOKU_CLIENT_ID` dan `DOKU_SECRET_KEY` dari dashboard DOKU sandbox.
- Pastikan `DOKU_NOTIFICATION_URL` mengarah ke domain public backend: `https://iqroku.motionmind.store/payments/doku/webhook`.
- Jalankan migration setelah pull: `npm run migrate --prefix backend`.
- Production premium aktif hanya dari webhook DOKU valid signature; client tidak boleh mengaktifkan subscription langsung.
- Email saat ini mengirim kode manual karena app belum memakai universal/deep link.

Database performance:

- Migration `008_performance_indexes.sql` menambah index idempotent untuk query production yang sering dipakai.
- Jalankan `npm run migrate --prefix backend` setelah pull sebelum restart PM2.
- Untuk tabel kecil efeknya belum terasa, tapi ini mencegah dashboard, notification, payment, dan review flow melambat saat data membesar.

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

## Monitoring and Operations Checks

Manual ops check:

```bash
cd /opt/iqroku
BASE_URL=https://iqroku.motionmind.store ./deploy/ops-check.sh
```

The one-time setup and deploy script copy this script to `/opt/iqroku/ops-check.sh` and install cron:

```bash
*/15 * * * * BASE_URL=https://iqroku.motionmind.store /opt/iqroku/ops-check.sh >> /var/log/iqroku/ops-check.log 2>&1
```

What it checks:

- `/health` returns `ok=true` and `store=postgresql`.
- PM2 process `iqroku` has a running PID.
- Migration status command succeeds.
- Latest DB backup exists, is gzip-valid, and is fresh.
- Latest uploads backup is tar-valid when present.
- Disk usage is below `DISK_WARN_PERCENT`, default `85`.
- `/opt/iqroku/backend/.env` permission is `600` or stricter.
- Firebase service account file permission is `600` or stricter when configured.
- Live Nginx does not serve `/uploads/` through a public `alias`.

Common commands:

```bash
tail -n 100 /var/log/iqroku/ops-check.log
tail -n 100 /var/log/iqroku/backup.log
BACKUP_MAX_AGE_HOURS=48 DISK_WARN_PERCENT=90 ./deploy/ops-check.sh
CHECK_MIGRATIONS=false ./deploy/ops-check.sh
OPS_BASE_URL=https://iqroku.motionmind.store ./deploy/deploy.sh
```

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

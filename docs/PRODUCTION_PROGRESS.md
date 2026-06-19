# Production Progress

Dokumen ini mencatat pekerjaan production readiness yang sudah masuk supaya perubahan berikutnya punya konteks.

## Selesai Pada Tahap Ini

### 1. Backend dan Database Foundation

- Menambahkan migration runner backend:
  - `npm run migrate`
  - `npm run migrate:status`
- Menambahkan folder migration:
  - `deploy/migrations/001_production_foundation.sql`
- Menambahkan tabel `schema_migrations` untuk melacak migration yang sudah jalan.
- Menambahkan `CREATE EXTENSION IF NOT EXISTS pgcrypto` untuk `gen_random_uuid()`.
- Menambahkan index production untuk query yang sering dipakai:
  - children by parent
  - progress by child/book/page
  - attempts by child/review
  - unread notifications
  - active daily prayers
  - auth token lookup
- Menambahkan `attempts.reviewed_by` untuk audit review parent.
- Membuat upload audio root configurable via `IQROKU_UPLOAD_ROOT`.

### 2. Auth Production Foundation

- Menambahkan kolom parent:
  - `email_verified`
  - `email_verified_at`
  - `updated_at`
- Menambahkan tabel `auth_tokens` untuk token sekali pakai.
- Token mentah tidak disimpan di database; backend menyimpan SHA-256 hash.
- Menambahkan endpoint:
  - `POST /auth/verify-email`
  - `POST /auth/resend-verification`
  - `POST /auth/password-reset/request`
  - `POST /auth/password-reset/confirm`
- Menambahkan env:
  - `REQUIRE_EMAIL_VERIFICATION`
  - `AUTH_LINK_BASE_URL`
  - `EMAIL_VERIFICATION_TTL_MINUTES`
  - `PASSWORD_RESET_TTL_MINUTES`

### 3. Auth UI Foundation

- Menambahkan layar verifikasi email di Flutter.
- Menambahkan tombol resend verification.
- Menambahkan layar reset password dari tombol `Lupa password?`.
- Menambahkan flow:
  - request kode reset
  - input kode reset
  - input password baru
  - kembali ke login setelah sukses
- Saat local/development, token dari backend bisa dipakai untuk mengisi kode manual.

### 4. Security, Codebase, dan Database Hardening

- Menambahkan migration:
  - `deploy/migrations/002_security_constraints.sql`
- Menambahkan constraint database untuk status penting:
  - `progress.status`
  - `progress.review_status`
  - `attempts.assessment_status`
  - `attempts.review_status`
  - `attempts.status`
  - `auth_tokens.purpose`
  - `notifications.user_type`
- Menambahkan foreign key audit review:
  - `attempts.reviewed_by -> parents.id`
  - `progress.reviewed_by -> parents.id`
- Mengubah approve/repeat review menjadi satu transaksi database supaya attempt, progress, repeat pointer, dan notifikasi tidak bisa setengah tersimpan.
- Menghapus jalur review lama di route dan memusatkan keputusan parent ke helper `approveReview` dan `repeatReview`.
- Menambahkan validasi upload audio:
  - batas ukuran via `MAX_AUDIO_UPLOAD_BYTES`
  - allowlist MIME/content type
  - allowlist ekstensi audio
  - sniffing header dasar untuk WAV, MP3, MP4/M4A, dan WebM
- Menambahkan header `X-Content-Type-Options: nosniff` untuk response JSON/file.
- Menambahkan `Vary: Origin` untuk response JSON.
- Menambahkan `Secure` attribute pada cookie admin saat `NODE_ENV=production`.
- Menambahkan regression test untuk security guard di backend.

### 5. Deployment dan Backup Foundation

- Memperkuat `deploy/setup-vps.sh`:
  - env production dibuat lebih lengkap
  - password database dirotasi saat setup ulang
  - bootstrap Nginx HTTP-only sebelum mengambil SSL certificate
  - SSL diambil lewat Certbot webroot sebelum config HTTPS final dipasang
  - domain dan app directory bisa dioverride via env
- Memperkuat `deploy/deploy.sh`:
  - menolak deploy jika `backend/.env` belum ada
  - backup wajib sebelum pull/migration
  - menjalankan syntax check backend
  - menjalankan `npm audit --omit=dev --audit-level=high`
  - menjalankan migration
  - menjalankan smoke test setelah PM2 restart
  - rollback code jika smoke test gagal
- Menambahkan `deploy/smoke-test.sh` untuk cek health, security header, syntax backend, dan status migration.
- Menambahkan `deploy/restore-backup.sh` untuk restore drill database dan uploads dengan konfirmasi eksplisit `CONFIRM_RESTORE=YES`.
- Memperkuat `deploy/backup.sh` agar app dir, backup dir, DB name, dan retention bisa dioverride via env serta hasil gzip diverifikasi.

### 6. CI Foundation

- Menambahkan GitHub Actions workflow `.github/workflows/ci.yml`.
- CI berjalan untuk push dan pull request ke `main`.
- Job backend menjalankan:
  - install dependency
  - PostgreSQL service
  - migration `001` dan `002`
  - migration status
  - syntax check
  - backend test
  - `npm audit --omit=dev --audit-level=high`
- Job Flutter menjalankan:
  - `flutter pub get`
  - `flutter analyze`
  - `flutter test`
- Job deploy scripts menjalankan:
  - bash syntax check untuk script deploy/backup/restore/smoke
  - whitespace check

### 7. Onboarding Database Drift Fix

- Menambahkan migration `deploy/migrations/003_onboarding_profile_columns.sql`.
- Migration ini membackfill kolom yang dipakai runtime tetapi bisa belum ada di database production lama:
  - `parents.pin_hash`
  - `children.pin_hash`
  - `children.study_start_time`
  - `children.study_end_time`
  - `children.study_days`
  - `progress.reviewed_by`
- Fix ini mencegah parent/child PIN selalu dianggap belum diset pada database lama.

### 8. Review Flow Database Drift Fix

- Menambahkan migration `deploy/migrations/004_review_flow_columns.sql`.
- Migration ini membackfill kolom yang dipakai parent review dan audio attempt tetapi bisa belum ada di database production lama:
  - `progress.reviewed_at`
  - `progress.review_status`
  - `attempts.reviewed_at`
  - `attempts.review_status`
  - `attempts.assessment_status`
  - `attempts.status`
  - `attempts.audio_*`
  - `children.repeat_from_page`
  - `children.repeat_from_book`
- Fix ini mencegah approve/repeat review gagal karena missing column di database lama.

### 9. Jadwal Adzan Lokal

- Menambahkan dependency Flutter:
  - `flutter_local_notifications`
  - `flutter_timezone`
  - `timezone`
- Menambahkan `PrayerReminderService` untuk menjadwalkan pengingat adzan lokal.
- Menambahkan switch `Suara adzan otomatis` di halaman Jadwal Solat.
- Saat user mengaktifkan switch, app meminta izin notifikasi dan menjadwalkan Subuh, Dzuhur, Ashar, Maghrib, dan Isya.
- Saat jadwal solat dimuat ulang, jadwal adzan ikut disusun ulang.
- Menambahkan permission Android:
  - `POST_NOTIFICATIONS`
  - `VIBRATE`
  - `RECEIVE_BOOT_COMPLETED`
- Menambahkan receiver Android untuk scheduled notification dan reschedule setelah device boot/package update.
- Setting adzan disimpan di local storage agar tetap aktif setelah app dibuka ulang.

### 10. FCM Push Notification Foundation

- Menambahkan dependency Flutter:
  - `firebase_core`
  - `firebase_messaging`
- Menambahkan `PushNotificationService` untuk:
  - initialize Firebase Messaging
  - meminta izin notifikasi
  - mengambil token FCM
  - register token ke backend setelah login/session restore
  - unregister token saat logout
- Menambahkan migration:
  - `deploy/migrations/005_device_tokens.sql`
- Menambahkan tabel `device_tokens` untuk token perangkat parent/child.
- Menambahkan endpoint backend:
  - `POST /devices/register`
  - `POST /devices/unregister`
- Menambahkan sender FCM HTTP v1 di backend tanpa dependency `firebase-admin`.
- Backend bisa membaca Firebase service account dari:
  - `FIREBASE_SERVICE_ACCOUNT_JSON`
  - `FIREBASE_SERVICE_ACCOUNT_PATH`
  - `GOOGLE_APPLICATION_CREDENTIALS`
- Event `new_recording` dan `review_result` sudah disambungkan ke push sender. Jika service account belum ada, pengiriman push di-skip dengan log.
- Menambahkan migration `deploy/migrations/006_device_token_roles.sql` supaya satu token FCM bisa terdaftar untuk parent dan child sekaligus.
- Token child sekarang diregister setelah PIN mode anak berhasil.
- Android notification small icon memakai drawable khusus `ic_stat_iqroku_notification` agar tidak tampil sebagai icon launcher kotak.
- Menambahkan audio adzan custom Android:
  - `adzan.mp3` untuk Dzuhur, Ashar, Maghrib, dan Isya
  - `adzan_subuh.mp3` untuk Subuh
- Channel notifikasi adzan dipisah antara regular dan Subuh agar masing-masing bisa memakai sound yang tepat.

### 11. Security Hardening dari Audit VPS

- Menambahkan backend scheduler untuk cleanup auth data expired:
  - `sessions` expired
  - `auth_tokens` expired lebih dari 7 hari
- `setup-vps.sh` sekarang memasang cron cleanup untuk `sessions` dan `auth_tokens`.
- Session token tidak lagi menyertakan `parentId`; format token menjadi random opaque token.
- `escapeHtml` admin template sekarang juga escape backtick.
- `deploy/deploy.sh` menolak deploy jika live Nginx masih melayani `/uploads/` memakai `alias /opt/iqroku/uploads/`, karena itu bypass auth backend.
- `deploy/README.md` menambahkan command VPS untuk sync Nginx live config dan mengunci permission Firebase service account ke `600`.

## Belum Selesai

- Email provider belum disambungkan. Saat development, token/link ditulis ke log backend. Saat production, backend hanya mencatat event `auth_token_created` tanpa membocorkan token.
- Email verification dan forgot password UI sudah ada, tetapi belum memakai deep link email otomatis.
- `REQUIRE_EMAIL_VERIFICATION` sebaiknya tetap `false` sampai email delivery dan UI sudah siap end-to-end.
- Audio masih disimpan di filesystem persistent path. Untuk scale lebih besar, pindahkan ke object storage/private bucket.
- Rate limit saat ini masih in-memory per proses. Untuk production multi-instance, pindahkan ke Redis atau provider rate limit terpusat.
- Belum ada audit dependency otomatis di CI.
- Restore script sudah ada, tetapi restore drill nyata di VPS/staging belum dijalankan dan dicatat hasilnya.
- Jadwal adzan memakai mode inexact-while-idle. Jika nanti butuh alarm presisi menit, tambahkan flow izin exact alarm dan validasi kebijakan store.
- Service account Firebase Admin belum dipasang di VPS. Push token sudah bisa tersimpan, tetapi pengiriman push butuh env service account.
- Perlu test device nyata setelah APK baru dipasang untuk memastikan permission FCM dan rendering icon sesuai variasi Android vendor.
- Admin dashboard masih membaca beberapa dataset besar ke memory; perlu query agregasi/pagination sebelum traffic besar.
- Admin IP restriction di Nginx masih optional dan perlu diaktifkan manual kalau IP admin sudah stabil.

## Cara Jalankan Migration

Local:

```powershell
cd d:\MotionMind\iqroku
npm run migrate --prefix backend
```

Production:

```bash
cd /opt/iqroku
npm run migrate --prefix backend
pm2 restart iqroku
```

Status migration:

```bash
npm run migrate:status --prefix backend
```

## Endpoint Auth Baru

Verifikasi email:

```http
POST /auth/verify-email
Content-Type: application/json

{ "token": "raw-token-from-email" }
```

Kirim ulang verifikasi:

```http
POST /auth/resend-verification
Content-Type: application/json

{ "email": "parent@example.com" }
```

Minta reset password:

```http
POST /auth/password-reset/request
Content-Type: application/json

{ "email": "parent@example.com" }
```

Konfirmasi reset password:

```http
POST /auth/password-reset/confirm
Content-Type: application/json

{ "token": "raw-token-from-email", "password": "new-password" }
```

## Catatan Security

- Request reset password dan resend verification selalu mengembalikan `{ "ok": true }` supaya tidak membocorkan apakah email terdaftar.
- Login bisa menolak akun belum verified jika `REQUIRE_EMAIL_VERIFICATION=true`.
- Google login menandai email verified karena token Google sudah dicek `email_verified`.
- Semua token reset/verify bersifat one-time dan punya expiry.
- Review parent sekarang transactional. Jika salah satu update gagal, seluruh perubahan review rollback.
- Constraint database mencegah status di luar enum aplikasi masuk ke tabel utama.
- Upload audio yang bukan tipe audio valid ditolak sebelum ditulis ke storage.

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

## Belum Selesai

- Email provider belum disambungkan. Saat development, token/link ditulis ke log backend. Saat production, backend hanya mencatat event `auth_token_created` tanpa membocorkan token.
- Email verification dan forgot password UI sudah ada, tetapi belum memakai deep link email otomatis.
- `REQUIRE_EMAIL_VERIFICATION` sebaiknya tetap `false` sampai email delivery dan UI sudah siap end-to-end.
- Audio masih disimpan di filesystem persistent path. Untuk scale lebih besar, pindahkan ke object storage/private bucket.
- Rate limit saat ini masih in-memory per proses. Untuk production multi-instance, pindahkan ke Redis atau provider rate limit terpusat.
- Belum ada audit dependency otomatis di CI.
- Belum ada backup/restore drill database yang terdokumentasi hasilnya.

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

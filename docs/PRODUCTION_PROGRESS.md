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

## Belum Selesai

- Email provider belum disambungkan. Saat development, token/link ditulis ke log backend. Saat production, backend hanya mencatat event `auth_token_created` tanpa membocorkan token.
- UI Flutter untuk verifikasi email dan forgot password belum dibuat.
- `REQUIRE_EMAIL_VERIFICATION` sebaiknya tetap `false` sampai email delivery dan UI sudah siap end-to-end.
- Audio masih disimpan di filesystem persistent path. Untuk scale lebih besar, pindahkan ke object storage/private bucket.

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

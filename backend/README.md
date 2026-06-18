# IqroKu Backend

Node.js API untuk auth, child profile, progress Iqro, rekaman audio, review orang tua, subscription, notifikasi, daily prayers, dan admin dashboard.

## Run

```bash
cd backend
npm install
npm start
```

Default URL: `http://localhost:8787`

## Validate

```bash
cd backend
npm run migrate:status
npm run check
npm test
```

## Environment Variables

Lihat `deploy/.env.production` untuk template production.

Variable penting:

```text
PORT
DATABASE_URL
IQROKU_ADMIN_TOKEN
IQROKU_UPLOAD_ROOT
REQUIRE_EMAIL_VERIFICATION
AUTH_LINK_BASE_URL
```

## Authentication

Protected endpoints memakai bearer token:

```text
Authorization: Bearer <session_token>
```

Token dikembalikan oleh `/auth/register`, `/auth/login`, dan `/auth/google`.

## Admin Dashboard

Admin route membutuhkan admin token:

```text
http://localhost:8787/admin?token=admin-dev-token
```

Atau:

```text
Authorization: Bearer admin-dev-token
```

## Dokumentasi Lanjut

- Arsitektur: `../docs/ARCHITECTURE.md`
- Flow produk: `../docs/FLOWS.md`
- Panduan perubahan: `../docs/CHANGE_GUIDE.md`
- Progress production: `../docs/PRODUCTION_PROGRESS.md`
- Deploy VPS: `../deploy/README.md`

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
- Deploy VPS: `../deploy/README.md`

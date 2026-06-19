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
FIREBASE_SERVICE_ACCOUNT_PATH
FIREBASE_SERVICE_ACCOUNT_JSON
DOKU_CLIENT_ID
DOKU_SECRET_KEY
DOKU_NOTIFICATION_URL
```

`FIREBASE_SERVICE_ACCOUNT_PATH` atau `FIREBASE_SERVICE_ACCOUNT_JSON` hanya diperlukan jika backend harus mengirim push notification FCM. Tanpa env ini, endpoint token tetap aktif tetapi pengiriman push akan di-skip.

`DOKU_CLIENT_ID` dan `DOKU_SECRET_KEY` diperlukan untuk membuat DOKU Checkout dan menerima webhook payment.

## Authentication

Protected endpoints memakai bearer token:

```text
Authorization: Bearer <session_token>
```

Token dikembalikan oleh `/auth/register`, `/auth/login`, dan `/auth/google`.

## Payments

```text
POST /payments/doku/checkout
POST /payments/doku/webhook
GET  /subscriptions/status
GET  /payments/status/:invoiceNumber
```

Checkout/status memakai bearer token parent. Webhook DOKU public tetapi wajib valid signature sebelum subscription diaktifkan.

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

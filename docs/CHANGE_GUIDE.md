# Panduan Perubahan

Gunakan dokumen ini untuk tahu file mana yang biasanya perlu diubah saat fitur berubah.

## Mengubah Aturan Premium

File utama:

```text
iqroku_app/lib/app/app_state.dart
iqroku_app/lib/core/widgets/subscription_sheet.dart
iqroku_app/lib/features/learning/learning_screen.dart
iqroku_app/lib/features/profile/profile_screen.dart
backend/src/server.mjs
backend/src/db.mjs
deploy/schema.sql
```

Yang perlu dicek:

- `freeIqroBookLimit`
- `familyPlusActive`
- `shouldShowAds`
- `isIqroBookPremiumLocked()`
- `isIqroPageLocked()`
- `selectIqroBook()`
- `selectIqroPage()`
- subscription response dari backend

Jika payment gateway sudah siap, jangan pakai aktivasi manual sebagai sumber truth production. Buat webhook payment yang memverifikasi signature, lalu update tabel `subscriptions`.

## Mengubah Flow Review Orang Tua

File utama:

```text
iqroku_app/lib/app/app_state.dart
iqroku_app/lib/features/mode/parent_dashboard_screen.dart
iqroku_app/lib/features/learning/learning_screen.dart
backend/src/server.mjs
backend/src/db.mjs
deploy/schema.sql
```

Endpoint terkait:

```text
GET  /reviews/pending
POST /reviews/approve
POST /reviews/repeat
```

Hal yang wajib dijaga:

- AI tidak menentukan hasil bacaan.
- Parent adalah sumber keputusan lancar/perlu ulang.
- Jika parent memilih perlu ulang dari halaman tertentu, anak harus mulai dari halaman itu.
- UI mode anak harus mengikuti status review terbaru.
- Pending review harus hilang setelah parent memberi keputusan.

## Mengubah Rekaman dan Playback Audio

File utama:

```text
iqroku_app/lib/app/app_state.dart
iqroku_app/lib/core/services/
iqroku_app/lib/features/learning/learning_screen.dart
iqroku_app/lib/features/mode/parent_dashboard_screen.dart
backend/src/server.mjs
backend/src/db.mjs
```

Checklist:

- Upload audio berhasil dan attempt menyimpan referensi audio.
- Parent bisa playback dengan auth.
- Anak/profil bisa playback attempt miliknya.
- Error playback tampil ramah di UI.
- Backend menolak akses audio milik parent lain.

## Mengubah Auth, Register, dan Setup

File utama:

```text
iqroku_app/lib/features/auth/login_screen.dart
iqroku_app/lib/features/auth/register_screen.dart
iqroku_app/lib/app/app_state.dart
backend/src/server.mjs
backend/src/db.mjs
```

Aturan produk saat ini:

- Register memakai email/password dan wajib setuju legal docs.
- Google login hanya ada di halaman login awal.
- Setelah register pertama kali, user masuk ke setup keluarga.

Jika menambah email verification:

- Tambahkan tabel/token verifikasi.
- Jangan aktifkan akun penuh sebelum email terverifikasi, kecuali ada flow trial yang jelas.
- Pastikan resend verification punya rate limit.

## Mengubah Legal Docs

File utama:

```text
iqroku_app/lib/core/widgets/legal_documents.dart
iqroku_app/lib/features/auth/register_screen.dart
iqroku_app/lib/features/profile/profile_screen.dart
```

Pastikan:

- Checkbox register tetap mengarah ke Syarat & Ketentuan dan Privacy Policy.
- Profile/settings tetap bisa membuka kedua dokumen.
- Versi teks legal dicatat jika nanti perlu audit consent.

## Menambah Payment Gateway

Flow DOKU Checkout sudah punya fondasi backend:

1. App meminta checkout/session ke backend.
2. Backend membuat invoice di `payment_orders`.
3. Backend membuat DOKU Checkout dan mengembalikan `checkoutUrl`.
4. User membayar di halaman hosted DOKU.
5. DOKU memanggil `POST /payments/doku/webhook`.
6. Backend memverifikasi signature webhook dan menyimpan `payment_events`.
7. Jika order valid berubah menjadi `paid`, backend mengaktifkan `subscriptions`.
8. App refresh `GET /subscriptions/status` saat kembali dari browser DOKU dan membuka premium.

Endpoint backend:

```text
POST /payments/doku/checkout
POST /payments/doku/webhook
GET  /subscriptions/status
GET  /payments/status/:invoiceNumber
```

Env production:

```text
DOKU_ENV=sandbox
DOKU_CLIENT_ID=
DOKU_SECRET_KEY=
DOKU_BASE_URL=https://api-sandbox.doku.com
DOKU_NOTIFICATION_URL=https://iqroku.motionmind.store/payments/doku/webhook
```

File yang kemungkinan disentuh:

```text
backend/src/server.mjs
backend/src/db.mjs
deploy/schema.sql
deploy/migrations/007_doku_payments.sql
iqroku_app/lib/app/app_state.dart
iqroku_app/lib/core/widgets/subscription_sheet.dart
iqroku_app/lib/features/profile/profile_screen.dart
```

Jangan percaya status premium dari client. Client hanya menampilkan UI, backend harus menjadi sumber truth.

## Menambah Ads

Aturan produk:

- Ads muncul untuk user free.
- Ads tidak boleh menghalangi belajar inti secara berlebihan.
- Fitur free tetap bisa dipakai walaupun ada ads.

File utama:

```text
iqroku_app/lib/app/app_state.dart
iqroku_app/lib/features/home/
iqroku_app/lib/features/activity/
iqroku_app/lib/features/quran/
iqroku_app/lib/features/learning/
```

Gunakan `shouldShowAds` sebagai flag utama agar saat user subscribe semua slot iklan bisa hilang konsisten.

## Mengubah Asset/Icon

File utama:

```text
iqroku_app/pubspec.yaml
iqroku_app/lib/features/
iqroku_app/lib/core/
```

Langkah:

1. Tambahkan file asset.
2. Daftarkan di `pubspec.yaml`.
3. Pakai `Image.asset(...)`.
4. Jalankan `flutter analyze`.
5. Cek tampilan di layar kecil dan besar.

## Validasi Setelah Perubahan

Backend:

```powershell
cd backend
npm run check
npm test
```

Flutter:

```powershell
cd iqroku_app
flutter analyze
flutter test
flutter build web
```

Untuk perubahan UI besar, jalankan app local dan cek minimal:

- login/register
- mode anak
- rekam bacaan
- parent review
- premium lock
- legal docs

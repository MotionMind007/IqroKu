# Arsitektur IqroKu

Dokumen ini menjelaskan bentuk sistem saat ini supaya perubahan berikutnya punya pegangan yang jelas.

## Gambaran Sistem

IqroKu terdiri dari dua aplikasi utama:

- `iqroku_app/`: Flutter app untuk user anak dan orang tua.
- `backend/`: Node.js API untuk auth, data anak, progress, rekaman audio, review orang tua, subscription, notifikasi, dan admin.

Deployment VPS ada di `deploy/` dan memakai PostgreSQL, PM2, serta Nginx.

## Frontend Flutter

State utama aplikasi ada di:

- `iqroku_app/lib/app/app_state.dart`

File ini mengatur:

- sesi login dan setup keluarga
- mode anak/orang tua
- child profile aktif
- progress Iqro
- status subscription
- rekaman dan playback audio
- pending review orang tua
- gate premium dan slot iklan

Screen utama tersebar di:

```text
iqroku_app/lib/features/auth/       Login, register, setup awal
iqroku_app/lib/features/home/       Dashboard anak
iqroku_app/lib/features/learning/   Iqro, rekaman, status halaman
iqroku_app/lib/features/mode/       Parent dashboard, PIN, mode switch
iqroku_app/lib/features/profile/    Profil, paket, legal docs
iqroku_app/lib/features/quran/      Al-Quran, Juz Amma, hafalan
iqroku_app/lib/features/activity/   Jadwal sholat, kiblat, aktivitas Islami
```

Model domain ada di:

```text
iqroku_app/lib/models/
```

Service API/audio/storage ada di:

```text
iqroku_app/lib/core/services/
iqroku_app/lib/data/
```

Service penting:

```text
PrayerReminderService        scheduler notifikasi adzan lokal
PushNotificationService      register token FCM dari app ke backend
IslamicActivityService       jadwal sholat dan arah kiblat
AudioPlaybackService         playback rekaman dan audio Qur'an
VoiceRecordingService        rekaman bacaan anak
```

## Backend API

Entry point backend:

- `backend/src/server.mjs`

Database access:

- `backend/src/db.mjs`

Route penting:

```text
GET  /health
GET  /daily-prayers
POST /auth/register
POST /auth/login
POST /auth/google
POST /auth/verify-email
POST /auth/resend-verification
POST /auth/password-reset/request
POST /auth/password-reset/confirm
GET  /children
POST /children
GET  /progress
PUT  /progress
GET  /attempts
POST /attempts
POST /attempts/:id/audio
POST /assessments/mock      disabled, returns 410
POST /assessments/ai        disabled, returns 410
POST /subscriptions/activate
POST /payments/doku/checkout
POST /payments/doku/webhook
GET  /payments/status/:invoiceNumber
POST /auth/set-parent-pin
POST /auth/verify-parent-pin
POST /auth/child-login
GET  /reviews/pending
POST /reviews/approve
POST /reviews/repeat
GET  /notifications
POST /notifications/:id/read
POST /notifications/read-all
```

Admin route:

```text
GET  /admin
GET  /admin/metrics
GET  /admin/prayers
POST /admin/prayers
POST /admin/prayers/:id/update
POST /admin/prayers/:id/delete
```

Protected user routes memakai `Authorization: Bearer <session_token>`.

## Database

Schema production ada di:

- `deploy/schema.sql`

Tabel utama:

```text
parents        akun orang tua, PIN parent, password hash
sessions       token sesi login
children       profil anak, gender, PIN anak, jadwal
progress       status halaman Iqro per anak
attempts       rekaman bacaan anak dan hasil review
subscriptions  status paket/premium
payment_orders checkout DOKU dan status invoice
payment_events webhook DOKU idempotent
notifications  notifikasi untuk parent
device_tokens  token FCM perangkat untuk push notification
daily_prayers  jadwal doa harian/admin content
```

Catatan penting:

- `attempts.assessment_status` masih dipakai sebagai enum status UI lama, tetapi sumber keputusan sekarang adalah review orang tua.
- `attempts.review_status` membedakan `pending`, `approved`, dan `needs_repeat`.
- `progress.status` menjadi status halaman yang ditampilkan di app.
- Jika parent memilih perlu ulang dari halaman tertentu, progress halaman itu menjadi `review` dan anak wajib mulai dari halaman tersebut.
- Approve/repeat review dijalankan dalam transaksi database agar update attempt, progress, repeat pointer, dan notifikasi konsisten.
- Status utama di `progress`, `attempts`, `auth_tokens`, dan `notifications` dibatasi oleh database constraint dari migration `002_security_constraints.sql`.
- Subscription premium production harus berasal dari webhook payment yang valid, bukan dari input client.
- DOKU webhook diverifikasi dengan signature HMAC dan disimpan idempotent memakai `(provider, request_id)`.

## Push Notification

Push notification memakai Firebase Cloud Messaging (FCM).

Flutter:

- `firebase_core`
- `firebase_messaging`
- `PushNotificationService`
- Setelah login/restore session, app mencoba mengambil token FCM dan mengirimnya ke `POST /devices/register`.
- Android build membutuhkan `iqroku_app/android/app/google-services.json` lokal. File asli di-ignore; template aman ada di `google-services.example.json`.

Backend:

- `POST /devices/register` menyimpan token perangkat.
- `POST /devices/unregister` menonaktifkan token saat logout.
- Token tersimpan di tabel `device_tokens`.
- Token perangkat boleh tersimpan untuk parent dan child sekaligus supaya perangkat yang sama tetap menerima notifikasi untuk dua mode.
- Backend mengirim FCM HTTP v1 langsung memakai service account Firebase dan `node:crypto`, tanpa dependency `firebase-admin`.
- Jika env service account belum dipasang, backend tetap berjalan dan push akan di-skip dengan log.
- Android memakai small notification icon `ic_stat_iqroku_notification` dan warna `iqroku_notification_color`.

Env production/staging:

```text
FIREBASE_SERVICE_ACCOUNT_JSON='{"type":"service_account",...}'
# atau
FIREBASE_SERVICE_ACCOUNT_PATH=/opt/iqroku/secrets/firebase-service-account.json
```

Event yang sudah disiapkan untuk push:

- `new_recording` ke parent
- `review_result` ke child jika token child sudah diregister

## Asset

Asset visual app berada di root repo dan sebagian disalin/didaftarkan ke Flutter asset:

```text
parent.png
boykids.png
femalekids.png
hafalan.png
```

Saat menambah asset baru, pastikan file masuk ke `iqroku_app/pubspec.yaml` dan dipanggil dari widget yang sesuai.

Audio adzan:

- Fitur adzan Android memakai raw resource `adzan.mp3` untuk Dzuhur, Ashar, Maghrib, dan Isya.
- Subuh memakai raw resource terpisah `adzan_subuh.mp3`.
- File audio Android berada di `iqroku_app/android/app/src/main/res/raw/`.
- Channel Android yang sudah pernah dibuat tidak selalu mengganti sound otomatis; saat testing, reinstall app atau ganti channel id jika perlu.

## Keamanan Saat Ini

Backend sudah punya fondasi keamanan:

- session token untuk protected route
- validasi ownership data parent/child
- password hashing
- rate limiting dasar
- admin token untuk dashboard admin
- endpoint audio dilindungi untuk playback dari app
- deploy guard menolak live Nginx `/uploads/` yang memakai direct filesystem alias
- backend menjalankan cleanup `sessions` dan `auth_tokens` expired secara berkala
- session token berbentuk opaque random token tanpa menyertakan parent id
- validasi upload audio untuk ukuran, MIME/type, ekstensi, dan header dasar
- transaksi database untuk hasil review orang tua
- constraint database untuk status dan referensi reviewer
- header `X-Content-Type-Options: nosniff`
- cookie admin `Secure` saat production

Yang masih perlu diperkuat sebelum production:

- rotasi semua secret production
- HTTPS wajib
- rate limiting terpusat jika backend berjalan lebih dari satu proses/instance
- object storage/private bucket untuk audio jika skala naik
- payment webhook harus diverifikasi signature
- audit dependency dan backup restore
- monitoring error dan audit log untuk aksi parent/admin

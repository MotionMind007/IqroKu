# Production Checklist

Checklist ini untuk mengubah IqroKu dari prototype kuat menjadi production ready.

## Secrets dan Environment

- Ganti semua secret default.
- Set `IQROKU_ADMIN_TOKEN` yang kuat.
- Set database URL production dari secret manager atau env aman.
- Pastikan `.env.production` tidak berisi secret asli di Git.
- Pisahkan env local, staging, dan production.
- Aktifkan HTTPS untuk semua traffic.

## Database

- Jalankan schema dari `deploy/schema.sql` di database production.
- Jalankan migration dengan `npm run migrate --prefix backend`.
- Cek status migration dengan `npm run migrate:status --prefix backend`.
- Pastikan migration `002_security_constraints.sql` sudah `applied`.
- Pastikan migration `003_onboarding_profile_columns.sql` sudah `applied`.
- Pastikan status progress/attempt tidak memakai nilai di luar constraint schema.
- Buat backup otomatis harian.
- Tes restore backup memakai `deploy/restore-backup.sh` di staging.
- Tambahkan index jika query review/progress mulai besar.
- Pastikan data parent/child tidak bisa terbaca lintas akun.

## Auth dan Akun

- Email verification foundation tersedia di backend.
- Forgot password foundation tersedia di backend.
- UI verifikasi email dan forgot password tersedia di Flutter.
- Sambungkan email provider dan deep link sebelum mengaktifkan `REQUIRE_EMAIL_VERIFICATION=true`.
- Rate limit login, register, resend email, dan PIN verification.
- Audit session expiry dan logout.
- Simpan consent legal docs dengan versi dokumen jika dibutuhkan.

## Audio dan Storage

- Batas ukuran upload audio tersedia via `MAX_AUDIO_UPLOAD_BYTES`.
- Validasi MIME/type, ekstensi, dan header dasar audio sudah tersedia.
- Simpan audio di `IQROKU_UPLOAD_ROOT` pada persistent disk atau object storage.
- Pastikan audio private dan hanya bisa diakses pemiliknya.
- Tambahkan lifecycle policy untuk audio lama jika dibutuhkan.

## Subscription dan Payment

- Pilih payment gateway.
- Buat endpoint checkout/session.
- Buat webhook payment.
- Verifikasi signature webhook.
- Simpan event payment idempotent agar webhook dobel tidak merusak data.
- Jadikan backend sebagai sumber truth subscription.
- Uji sukses bayar, gagal bayar, expired, refund, dan cancel.

## Ads

- Pilih ads SDK.
- Tampilkan ads hanya saat `shouldShowAds=true`.
- Pastikan user premium bebas ads.
- Pastikan ads tidak muncul di flow sensitif seperti input PIN.
- Siapkan fallback jika ads gagal load.

## Flutter Release

- Setup Android signing key.
- Review package name, app name, icon, splash, dan permission.
- Build release APK/AAB.
- Tes di device Android low-end dan mid-end.
- Tes offline/poor network.
- Tes upgrade dari versi lama.

## Backend Release

- Pastikan GitHub Actions CI hijau di `main`.
- Jalankan `npm run check`.
- Jalankan `npm test`.
- Jalankan `npm audit --omit=dev --audit-level=high`.
- Jalankan `BASE_URL=https://iqroku.motionmind.store ./deploy/smoke-test.sh` di VPS.
- Tes health endpoint.
- Tes admin endpoint dengan token.
- Tes review pending, approve, repeat.
- Tes upload dan playback audio.
- Tes subscription state.

## Observability

- Tambahkan logging structured untuk request penting.
- Tambahkan error tracking.
- Monitor latency, error rate, storage usage, dan database connection.
- Buat alert untuk backend down, DB error, dan payment webhook gagal.

## Security Review

- Audit dependency.
- Audit ownership check semua route.
- Audit admin route.
- Audit upload audio setelah pindah object storage.
- Audit CORS.
- Pindahkan rate limit dari memory process ke Redis/provider terpusat sebelum multi-instance.
- Pastikan tidak ada secret di repo.
- Pastikan endpoint assessment AI tetap disabled kecuali ada desain baru yang jelas.
- Pastikan review parent tetap memakai transaksi database.

## Go-Live

- Deploy ke staging.
- Jalankan smoke test end-to-end.
- Backup database sebelum production deploy.
- Deploy production.
- Cek logs selama 30-60 menit pertama.
- Simpan rollback plan.

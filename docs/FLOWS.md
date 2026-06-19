# Flow Produk

Dokumen ini menjelaskan alur utama aplikasi saat ini.

## Register dan Setup Awal

1. User membuat akun dengan email dan password.
2. User menyetujui Syarat & Ketentuan serta Privacy Policy.
3. Setelah register, user masuk ke setup keluarga.
4. Parent membuat profil anak pertama.
5. App masuk ke pengalaman utama.

Catatan:

- Google login hanya tersedia di halaman login awal.
- Halaman buat akun tidak menampilkan tombol Google.
- Legal document ada di `iqroku_app/lib/core/widgets/legal_documents.dart`.
- Setelah register, user diarahkan ke layar verifikasi email. Selama `REQUIRE_EMAIL_VERIFICATION=false`, user masih bisa lanjut setup dulu.

## Flow Forgot Password

1. User membuka `Lupa password?` dari halaman login.
2. User memasukkan email.
3. Backend membuat token reset sekali pakai.
4. User memasukkan kode reset dan password baru.
5. Setelah berhasil, user kembali ke halaman login.

Catatan:

- Request reset selalu memberi response sukses agar tidak membocorkan email mana yang terdaftar.
- Saat production, kode dikirim lewat email provider. Saat local, kode bisa dilihat dari response/log development.

## Mode Anak dan Mode Orang Tua

Mode anak dipakai untuk belajar dan merekam bacaan.

Mode orang tua dipakai untuk:

- melihat dashboard keluarga
- review rekaman anak
- menentukan lancar atau perlu ulang
- mengatur PIN
- melihat notifikasi
- mengakses fitur free seperti jadwal sholat, Al-Quran, kiblat, doa-doa, dan murottal

Icon mode:

- orang tua: `parent.png`
- anak laki-laki: `boykids.png`
- anak perempuan: `femalekids.png`

## Flow Rekaman Anak

1. Anak memilih jilid dan halaman Iqro.
2. Anak menekan mulai rekam.
3. Anak menyelesaikan bacaan.
4. App membuat `attempt` dengan status review pending.
5. Rekaman dikirim ke backend.
6. Parent mendapat item pending review di dashboard.

AI tidak menentukan nilai. Endpoint assessment lama sengaja dimatikan dan mengembalikan `410 assessment_disabled`.

## Flow Review Orang Tua

Parent dashboard mengambil data dari:

```text
GET /reviews/pending
```

Parent bisa memutar rekaman dengan token auth. Playback memakai route audio attempt yang dilindungi backend.

Jika parent memilih lancar:

```text
POST /reviews/approve
```

Efeknya:

- attempt menjadi `review_status=approved`
- status attempt/progress menjadi lancar
- bar halaman berubah hijau
- tombol lancar menyala

Jika parent memilih perlu ulang:

```text
POST /reviews/repeat
```

Efeknya:

- attempt menjadi `review_status=needs_repeat`
- halaman repeat menjadi status review
- anak wajib mulai lagi dari halaman yang ditentukan parent
- tombol perlu ulang menyala

Contoh: anak membaca jilid 2 halaman 5 sampai 10. Parent meminta ulang dari halaman 8. Anak berikutnya diarahkan mulai dari halaman 8.

## Flow Premium dan Free

Aturan saat ini:

- Iqro jilid 1 free.
- Iqro jilid 2 sampai 6 premium.
- Jilid 2 sampai 6 tetap bisa diklik sebagai preview, tetapi halaman dikunci dengan tanda gembok.
- Jadwal sholat, kiblat, doa-doa, Al-Quran, dan murottal tetap free.
- Jika user belum subscribe, area fitur free bisa menampilkan slot iklan.

Logika utama ada di:

```text
iqroku_app/lib/app/app_state.dart
```

Konstanta penting:

```text
freeIqroBookLimit
familyPlusActive
shouldShowAds
subscriptionPriceLabel
```

Fondasi backend subscription:

```text
POST /subscriptions/activate
subscriptions table
```

Endpoint activate sekarang masih fondasi/prototype. Payment gateway production perlu webhook resmi.

## Flow Jadwal Solat dan Adzan

1. App memuat jadwal solat dari `IslamicActivityService`.
2. User membuka halaman Jadwal Solat.
3. User mengaktifkan switch `Suara adzan otomatis`.
4. App meminta izin notifikasi perangkat.
5. Jika izin diberikan, app menjadwalkan notifikasi adzan untuk Subuh, Dzuhur, Ashar, Maghrib, dan Isya.
6. Setiap jadwal solat dimuat ulang, jadwal notifikasi adzan ikut disusun ulang.

Catatan:

- Imsak dan Terbit tidak dipakai untuk suara adzan.
- Android memakai file raw `adzan.mp3` untuk Dzuhur, Ashar, Maghrib, dan Isya.
- Android memakai file raw `adzan_subuh.mp3` khusus untuk Subuh.
- Channel adzan dipisah antara regular dan Subuh karena Android menyimpan sound di level notification channel.
- Android 13+ membutuhkan izin notifikasi dari user.
- Android exact alarm belum dipakai supaya tidak perlu izin alarm khusus. Waktu notifikasi bisa mengikuti kebijakan idle/battery perangkat.

## Flow Push Notification

Push notification dipakai untuk notifikasi dari backend ke perangkat user.

1. User login atau session dipulihkan.
2. App menginisialisasi Firebase Messaging.
3. App meminta izin notifikasi perangkat.
4. App mengambil token FCM.
5. App mengirim token ke backend lewat:

```text
POST /devices/register
```

6. Backend menyimpan token di tabel `device_tokens`.
7. Saat ada event seperti rekaman baru atau hasil review, backend membuat record `notifications`, lalu mencoba mengirim push lewat FCM.
8. Jika token ditolak FCM karena sudah tidak valid, backend menonaktifkan token itu.
9. Saat logout, app memanggil:

```text
POST /devices/unregister
```

Catatan:

- Push akan aktif penuh setelah service account Firebase dipasang di env VPS.
- Kalau env belum ada, backend tetap aman dan hanya melewati pengiriman push.
- Token parent diregister setelah login/session restore.
- Token child diregister setelah PIN mode anak berhasil.
- Satu token perangkat bisa terdaftar sebagai parent dan child supaya HP yang sama tetap menerima notifikasi untuk dua mode.
- Android memakai small notification icon dedicated `ic_stat_iqroku_notification`, bukan launcher icon kotak.

## Flow Legal Docs

Legal docs bisa dibuka dari:

- checkbox register
- halaman profile/settings

Konten ada di:

```text
iqroku_app/lib/core/widgets/legal_documents.dart
```

Jika teks legal berubah, update satu file itu dan cek semua entry point tetap membuka modal yang benar.

## Flow Audio

Audio direkam di Flutter, lalu disimpan sebagai attempt audio.

Bagian penting:

- `VoiceRecordingService` untuk rekaman.
- `AudioPlaybackService` untuk playback.
- `AppState.toggleAttemptPlayback()` untuk playback di mode anak/profil.
- `AppState.toggleReviewPlayback()` untuk playback di parent dashboard.
- Backend route `/attempts/:id/audio` untuk upload/protected access.

Saat ada bug audio:

1. Cek attempt punya `audioUrl` atau audio path.
2. Cek token auth masih valid.
3. Cek backend ownership child/parent.
4. Cek file audio benar-benar ada di storage backend.
5. Cek service playback menerima URL protected atau bytes yang benar.
